using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tutorial11.Data;
using System.Text.Json;
using System.Text;
using Microsoft.Extensions.Configuration;
using System;
using System.Linq;
using System.Threading.Tasks;
using Tutorial11.Models; // Adicionado para garantir acesso aos teus modelos

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ChefController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly string _apiKey;

        // Injetamos a Base de Dados e a Configuração
        public ChefController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;

            // Vai ler a chave GeminiApiKey do appsettings.json. 
            // O '?? string.Empty' resolve o aviso amarelo CS8618.
            _apiKey = _configuration["GeminiApiKey"] ?? string.Empty;
        }

        [HttpGet("sugerir-jantar")]
        public async Task<IActionResult> SugerirJantar()
        {
            // 1. Extração: Ler o que está a expirar na Despensa (nos próximos 3 dias)
            var dataLimite = DateTime.Now.AddDays(3);

            // Primeiro, encontramos os IDs dos produtos que têm lotes a expirar e com quantidade superior a 0
            var lotesAExpirarIds = await _context.Stocks
                .SelectMany(s => s.Batches, (stock, batch) => new { stock.ProductId, batch.ExpirationDate, batch.Quantity })
                .Where(x => x.ExpirationDate <= dataLimite && x.Quantity > 0)
                .Select(x => x.ProductId)
                .Distinct()
                .ToListAsync();

            // Depois, vamos buscar o Nome real desses produtos à tabela Products usando os IDs encontrados
            var produtosAExpirar = await _context.Products
                .Where(p => lotesAExpirarIds.Contains(p.Id))
                .Select(p => p.Name)
                .ToListAsync();

            if (!produtosAExpirar.Any())
            {
                return Ok(new { receita = "Boas notícias! Não tens produtos prestes a expirar. Que tal encomendar uma pizza hoje?" });
            }

            string ingredientesStr = string.Join(", ", produtosAExpirar);

            // 2. RETRIEVAL (A parte 'R' do RAG) - Contexto
            string contextoDeReceitas = "Receitas Base: 1. Arroz de Forno (Arroz, Sobras de carne, Queijo). 2. Salada Fresca (Tomate, Alface, Atum). 3. Massa Rápida (Massa, Natas, Cogumelos).";

            // 3. GENERATION (A parte 'G' do RAG) - O Prompt Inteligente
            string prompt = $@"
                És um Chef de cozinha profissional e especialista em evitar o desperdício alimentar.
                O utilizador tem os seguintes ingredientes na despensa que vão expirar em breve: {ingredientesStr}.
                
                Aqui tens algumas receitas da nossa base de dados como contexto: {contextoDeReceitas}

                Cria uma receita deliciosa usando o MÁXIMO possível dos ingredientes a expirar. 
                Podes adicionar ingredientes básicos de cozinha (sal, azeite, alho).
                Formata a resposta em Markdown com:
                - Um título criativo.
                - Tempo de preparação.
                - Lista de ingredientes.
                - Passo-a-passo.
            ";

            // 4. Formatar o Payload exigido pelo Google Gemini
            var requestBody = new
            {
                contents = new[]
                {
                    new
                    {
                        parts = new[]
                        {
                            new { text = prompt }
                        }
                    }
                }
            };

            using var client = new HttpClient();
            var jsonContent = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

            // O endpoint do Gemini recebe a chave na Query String de forma segura pela injeção
            string geminiUrl = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key={_apiKey}";

            var response = await client.PostAsync(geminiUrl, jsonContent);

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                return StatusCode(500, $"O Chef Gemini está de folga hoje. Erro: {errorBody}");
            }

            // 5. Desmontar a resposta do Gemini
            var responseString = await response.Content.ReadAsStringAsync();
            using var jsonDocument = JsonDocument.Parse(responseString);

            // A estrutura de resposta do Gemini é: candidates[0].content.parts[0].text
            var receitaGerada = jsonDocument.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString();

            return Ok(new { receita = receitaGerada });
        }
    }
}