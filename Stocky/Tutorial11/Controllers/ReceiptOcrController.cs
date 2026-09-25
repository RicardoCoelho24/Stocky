using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using Tutorial11.DTOs;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class ReceiptOcrController : ControllerBase
    {
        // 1. INJETAR O LEITOR DE CONFIGURAÇÕES
        private readonly IConfiguration _configuration;

        public ReceiptOcrController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [HttpPost("analyze")]
        public async Task<IActionResult> AnalyzeReceipt(IFormFile image)
        {
            if (image == null || image.Length == 0)
                return BadRequest("Nenhuma imagem enviada.");

            using var memoryStream = new MemoryStream();
            await image.CopyToAsync(memoryStream);
            byte[] imageBytes = memoryStream.ToArray();
            string base64Image = Convert.ToBase64String(imageBytes);

            string mimeType = image.ContentType;
            if (string.IsNullOrEmpty(mimeType) || mimeType == "application/octet-stream")
            {
                mimeType = "image/jpeg";
            }

            // 2. IR BUSCAR A CHAVE DE FORMA SEGURA!
            string geminiApiKey = _configuration["GeminiApiKey"];

            try
            {
                using var client = new HttpClient();
                // ... (o resto do código fica igual a partir daqui!)
                client.Timeout = TimeSpan.FromSeconds(30);

                // NOVA INSTRUÇÃO COM A MAGIA DOS DESCONTOS
                var prompt = @"És um assistente especializado em ler faturas de supermercado. 
                Analisa esta imagem e devolve um objeto JSON válido (SEM formatação markdown) com esta estrutura exata:
                {
                    ""supermarketName"": ""Nome do Supermercado"",
                    ""totalDiscount"": 2.50,
                    ""items"": [
                        { ""productName"": ""Nome do Produto"", ""quantity"": 1.0, ""unitPrice"": 1.50 }
                    ]
                }
                REGRAS OBRIGATÓRIAS:
                1. Usa SEMPRE ponto (.) para casas decimais nos preços e quantidades, NUNCA vírgula (,).
                2. Se o produto tiver o formato '2 X 3,99', a quantity é 2 e o unitPrice é 3.99.
                3. Ignora linhas que sejam de IVA ou 'Total a Pagar'. Foca-te só nos produtos.
                4. CAÇA AOS DESCONTOS: Procura ativamente palavras como 'Desconto', 'Poupança', 'Cartão', 'Promoção' ou valores negativos (ex: -1.50). Soma esses valores e coloca o resultado TOTAL positivo (ex: 2.50) no campo 'totalDiscount'. Se não houver descontos, coloca 0.0.
                5. Responde APENAS com o JSON limpo, sem mais nenhum texto.";

                var requestBody = new
                {
                    contents = new[]
                    {
                        new
                        {
                            parts = new object[]
                            {
                                new { text = prompt },
                                new {
                                    inline_data = new
                                    {
                                        mime_type = mimeType,
                                        data = base64Image
                                    }
                                }
                            }
                        }
                    }
                };

                var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key={geminiApiKey}";

                var response = await client.PostAsJsonAsync(url, requestBody);

                if (response.IsSuccessStatusCode)
                {
                    var responseBody = await response.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(responseBody);

                    var textResponse = doc.RootElement.GetProperty("candidates")[0]
                        .GetProperty("content").GetProperty("parts")[0]
                        .GetProperty("text").GetString();

                    if (!string.IsNullOrWhiteSpace(textResponse))
                    {
                        var cleanJson = textResponse.Replace("```json", "").Replace("```", "").Trim();
                        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                        var result = JsonSerializer.Deserialize<ReceiptOcrResultDto>(cleanJson, options);

                        return Ok(result);
                    }
                }
                else
                {
                    var errorResponse = await response.Content.ReadAsStringAsync();
                    return BadRequest($"O Gemini rejeitou a imagem. Detalhes: {errorResponse}");
                }

                return BadRequest("A IA processou a imagem, mas devolveu um ficheiro em branco.");
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Erro a ler o JSON do Gemini: {ex.Message}");
            }
        }
    }
}