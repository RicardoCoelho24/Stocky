using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel;
using System.Security.Claims;
using System.Text.Json;
using Tutorial11.Data;
using Tutorial11.DTOs;
using Tutorial11.Models;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class PurchasesController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public PurchasesController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        [HttpPost]
        public async Task<ActionResult> CreatePurchase(PurchaseCreateDto request)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);
            if (user?.HouseholdId == null) return BadRequest("Casa não encontrada.");

            var nomeSuper = FormatarNome(request.SupermarketName);
            var supermarket = await _context.Supermarkets
                .FirstOrDefaultAsync(s => s.Name == nomeSuper);

            if (supermarket == null)
            {
                supermarket = new Supermarket { Name = nomeSuper };
                _context.Supermarkets.Add(supermarket);
                await _context.SaveChangesAsync();
            }

            var novaCompra = new Purchase
            {
                UserId = userId,
                HouseholdId = user.HouseholdId,
                SupermarketId = supermarket.Id,
                PurchaseDate = request.PurchaseDate,

                // NOVO: Guarda o desconto na base de dados!
                TotalDiscount = request.TotalDiscount,

                // MAGIA EXTRA: O Total da Compra agora é a (Soma dos Produtos) - (Desconto)
                TotalAmount = request.Items.Sum(i => i.Quantity * i.UnitPrice) - request.TotalDiscount
            };

            _context.Purchases.Add(novaCompra);
            await _context.SaveChangesAsync();

            foreach (var itemDto in request.Items)
            {
                var nomeProduto = FormatarNome(itemDto.ProductName);
                var produto = await _context.Products
                    .FirstOrDefaultAsync(p => p.Name == nomeProduto);

                if (produto == null)
                {
                    var categoriaIa = await InferirCategoriaComIA(nomeProduto);

                    produto = new Product
                    {
                        Name = nomeProduto,
                        Category = categoriaIa
                    };
                    _context.Products.Add(produto);
                    await _context.SaveChangesAsync();
                }

                var linhaCompra = new PurchaseItem
                {
                    PurchaseId = novaCompra.Id,
                    ProductId = produto.Id,
                    Quantity = itemDto.Quantity,
                    UnitPrice = itemDto.UnitPrice
                };
                _context.PurchaseItems.Add(linhaCompra);

                var stock = await _context.Stocks
                    .FirstOrDefaultAsync(s => s.HouseholdId == user.HouseholdId && s.ProductId == produto.Id);

                if (stock == null)
                {
                    stock = new Stock
                    {
                        UserId = userId,
                        HouseholdId = user.HouseholdId,
                        ProductId = produto.Id,
                        MinAlertThreshold = itemDto.MinAlertThreshold
                    };
                    _context.Stocks.Add(stock);
                    await _context.SaveChangesAsync();
                }

                var loteDeCompra = new StockBatch
                {
                    StockId = stock.Id,
                    Quantity = itemDto.Quantity,
                    ExpirationDate = itemDto.ExpirationDate,
                    DaysToAlertBeforeExpiration = itemDto.DaysToAlertBeforeExpiration
                };
                _context.StockBatches.Add(loteDeCompra);
            }

            await _context.SaveChangesAsync();

            return Ok(new { Message = "Compra registada com sucesso!" });
        }

        // ==========================================
        // MOTOR IA E FUNÇÕES AUXILIARES
        // ==========================================
        private async Task<string> InferirCategoriaComIA(string nomeProduto)
        {
            string geminiApiKey = _configuration["GeminiApiKey"];

            if (string.IsNullOrEmpty(geminiApiKey) || geminiApiKey.StartsWith("COLOCA"))
                return InferirCategoriaFallback(nomeProduto);

            try
            {
                using var client = new HttpClient();
                client.Timeout = TimeSpan.FromSeconds(10);

                var prompt = $"Classifica o produto '{nomeProduto}' estritamente numa destas categorias: Laticínios, Frutas e Legumes, Talho, Peixaria, Padaria e Pastelaria, Mercearia, Bebidas, Limpeza e Higiene. Responde APENAS com a categoria.";

                var requestBody = new { contents = new[] { new { parts = new[] { new { text = prompt } } } } };

                var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key={geminiApiKey}";

                var response = await client.PostAsJsonAsync(url, requestBody);

                if (response.IsSuccessStatusCode)
                {
                    var responseBody = await response.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(responseBody);
                    var textResponse = doc.RootElement.GetProperty("candidates")[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString();

                    if (!string.IsNullOrWhiteSpace(textResponse))
                    {
                        var categoriaLimpa = textResponse.Trim();
                        return char.ToUpper(categoriaLimpa[0]) + categoriaLimpa.Substring(1);
                    }
                }
            }
            catch { }

            return InferirCategoriaFallback(nomeProduto);
        }

        private string InferirCategoriaFallback(string nomeProduto)
        {
            var n = nomeProduto.ToLower();
            if (n.Contains("leite") || n.Contains("iogurte") || n.Contains("queijo") || n.Contains("manteiga") || n.Contains("natas")) return "Laticínios";
            if (n.Contains("maçã") || n.Contains("banana") || n.Contains("batata") || n.Contains("alface") || n.Contains("fruta") || n.Contains("legume")) return "Frutas e Legumes";
            if (n.Contains("bife") || n.Contains("frango") || n.Contains("carne") || n.Contains("chouriço") || n.Contains("fiambre")) return "Talho";
            if (n.Contains("peixe") || n.Contains("atum") || n.Contains("bacalhau") || n.Contains("marisco")) return "Peixaria";
            if (n.Contains("pão") || n.Contains("bolo") || n.Contains("donuts") || n.Contains("folhado")) return "Padaria e Pastelaria";
            if (n.Contains("água") || n.Contains("sumo") || n.Contains("vinho") || n.Contains("cerveja") || n.Contains("cola") || n.Contains("bebida") || n.Contains("fanta") || n.Contains("gatorade") || n.Contains("frize")) return "Bebidas";
            if (n.Contains("detergente") || n.Contains("champô") || n.Contains("gel") || n.Contains("lixívia") || n.Contains("limpeza")) return "Limpeza e Higiene";
            if (n.Contains("arroz") || n.Contains("massa") || n.Contains("azeite") || n.Contains("óleo") || n.Contains("bolacha") || n.Contains("cereais") || n.Contains("café")) return "Mercearia";

            return "Outros";
        }

        private string FormatarNome(string texto)
        {
            if (string.IsNullOrWhiteSpace(texto)) return texto;
            texto = texto.Trim().ToLower();
            return char.ToUpper(texto[0]) + texto.Substring(1);
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<object>>> GetMyPurchases()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);

            var purchases = await _context.Purchases
                .Where(p => p.HouseholdId == user!.HouseholdId)
                .OrderByDescending(p => p.PurchaseDate)
                .Select(p => new
                {
                    Id = p.Id,
                    SupermarketName = _context.Supermarkets.FirstOrDefault(s => s.Id == p.SupermarketId)!.Name,
                    PurchaseDate = p.PurchaseDate,
                    TotalAmount = p.TotalAmount,

                    // NOVO: Envia o Desconto no Histórico de volta para o Telemóvel!
                    TotalDiscount = p.TotalDiscount,

                    Items = _context.PurchaseItems
                        .Where(pi => pi.PurchaseId == p.Id)
                        .Select(pi => new
                        {
                            ProductName = _context.Products.FirstOrDefault(prod => prod.Id == pi.ProductId)!.Name,
                            Quantity = pi.Quantity,
                            UnitPrice = pi.UnitPrice,
                            TotalPrice = pi.Quantity * pi.UnitPrice
                        }).ToList()
                })
                .ToListAsync();

            return Ok(purchases);
        }
    }
}