using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel;
using System.Security.Claims;
using System.Text.Json;
using Tutorial11.Data;
using Tutorial11.DTOs;
using Tutorial11.Models;
using Tutorial11.Hubs;
using Microsoft.Extensions.Configuration; // Necessário para ler o appsettings

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class StocksController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IHubContext<HouseholdHub> _hubContext;
        private readonly IConfiguration _configuration;

        public StocksController(AppDbContext context, IHubContext<HouseholdHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<object>>> GetMyStock()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);
            if (user?.HouseholdId == null) return BadRequest("Casa não encontrada.");

            var meuStock = await _context.Stocks
                .Include(s => s.Batches)
                .Where(s => s.HouseholdId == user.HouseholdId)
                .Select(s => new
                {
                    StockId = s.Id,
                    ProdutoId = s.ProductId,
                    NomeProduto = _context.Products.FirstOrDefault(p => p.Id == s.ProductId)!.Name,
                    Categoria = _context.Products.FirstOrDefault(p => p.Id == s.ProductId)!.Category ?? "Outros",
                    Medida = _context.Products.FirstOrDefault(p => p.Id == s.ProductId)!.Measure,
                    QuantidadeAtual = s.Batches.Sum(b => b.Quantity),
                    AlertaMinimo = s.MinAlertThreshold,
                    ExpirationDate = s.Batches.Where(b => b.Quantity > 0 && b.ExpirationDate != null).OrderBy(b => b.ExpirationDate).Select(b => b.ExpirationDate).FirstOrDefault(),
                    DaysToAlertBeforeExpiration = s.Batches.Where(b => b.Quantity > 0 && b.ExpirationDate != null).OrderBy(b => b.ExpirationDate).Select(b => b.DaysToAlertBeforeExpiration).FirstOrDefault()
                })
                .ToListAsync();

            return Ok(meuStock);
        }

        [HttpPost("direct-add")]
        public async Task<ActionResult> DirectAddStock(StockDirectAddDto request)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);
            if (user?.HouseholdId == null) return BadRequest("Casa não encontrada.");

            var nomeLimpo = char.ToUpper(request.ProductName.Trim()[0]) + request.ProductName.Trim().Substring(1).ToLower();

            var produto = await _context.Products.FirstOrDefaultAsync(p => p.Name == nomeLimpo);
            if (produto == null)
            {
                var categoriaIa = await InferirCategoriaComIA(nomeLimpo);
                produto = new Product { Name = nomeLimpo, Category = categoriaIa };
                _context.Products.Add(produto);
                await _context.SaveChangesAsync();
            }

            var stock = await _context.Stocks.FirstOrDefaultAsync(s => s.HouseholdId == user.HouseholdId && s.ProductId == produto.Id);
            if (stock == null)
            {
                stock = new Stock
                {
                    UserId = userId,
                    HouseholdId = user.HouseholdId,
                    ProductId = produto.Id,
                    MinAlertThreshold = request.MinAlertThreshold
                };
                _context.Stocks.Add(stock);
                await _context.SaveChangesAsync();
            }

            var novoLote = new StockBatch
            {
                StockId = stock.Id,
                Quantity = request.Quantity,
                ExpirationDate = request.ExpirationDate,
                DaysToAlertBeforeExpiration = request.DaysToAlertBeforeExpiration
            };
            _context.StockBatches.Add(novoLote);

            await _context.SaveChangesAsync();

            // AVISAR TELEMÓVEIS DA CASA
            await _hubContext.Clients.Group(user.HouseholdId.ToString()!).SendAsync("UpdateStock");

            return Ok(new { Message = "Produto adicionado diretamente à despensa!" });
        }

        [HttpPut("quantity/{productId}")]
        public async Task<IActionResult> UpdateQuantity(int productId, [FromBody] StockQuantityUpdateDto request)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);

            var stock = await _context.Stocks.Include(s => s.Batches)
                .FirstOrDefaultAsync(s => s.HouseholdId == user!.HouseholdId && s.ProductId == productId);

            if (stock == null) return NotFound("Produto não encontrado.");

            var totalQty = stock.Batches.Sum(b => b.Quantity);
            var diff = request.NewQuantity - totalQty;

            if (diff > 0)
            {
                var lote = stock.Batches.OrderByDescending(b => b.ExpirationDate.HasValue ? 1 : 0).ThenByDescending(b => b.ExpirationDate).FirstOrDefault();
                if (lote != null)
                {
                    lote.Quantity += diff;
                }
                else
                {
                    stock.Batches.Add(new StockBatch { StockId = stock.Id, Quantity = diff });
                }
            }
            else if (diff < 0)
            {
                decimal qtyToConsume = Math.Abs(diff);
                var lotesOrdenados = stock.Batches
                    .Where(b => b.Quantity > 0)
                    .OrderBy(b => b.ExpirationDate.HasValue ? 0 : 1)
                    .ThenBy(b => b.ExpirationDate)
                    .ToList();

                foreach (var lote in lotesOrdenados)
                {
                    if (qtyToConsume <= 0) break;

                    if (lote.Quantity <= qtyToConsume)
                    {
                        qtyToConsume -= lote.Quantity;
                        lote.Quantity = 0;
                    }
                    else
                    {
                        lote.Quantity -= qtyToConsume;
                        qtyToConsume = 0;
                    }
                }
            }

            await _context.SaveChangesAsync();

            // AVISAR TELEMÓVEIS DA CASA
            await _hubContext.Clients.Group(user!.HouseholdId.ToString()!).SendAsync("UpdateStock");

            return Ok(new { Message = "Quantidade atualizada." });
        }

        [HttpPut("threshold/{productId}")]
        public async Task<IActionResult> UpdateThreshold(int productId, [FromBody] StockThresholdUpdateDto request)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);

            var stock = await _context.Stocks.FirstOrDefaultAsync(s => s.HouseholdId == user!.HouseholdId && s.ProductId == productId);
            if (stock == null) return NotFound("Produto não encontrado.");

            stock.MinAlertThreshold = request.NewThreshold;
            await _context.SaveChangesAsync();

            // AVISAR TELEMÓVEIS DA CASA
            await _hubContext.Clients.Group(user!.HouseholdId.ToString()!).SendAsync("UpdateStock");

            return Ok(new { Message = "Alerta atualizado." });
        }

        [HttpPut("expiration/{productId}")]
        public async Task<IActionResult> UpdateExpiration(int productId, [FromBody] StockExpirationUpdateDto request)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);

            var stock = await _context.Stocks.Include(s => s.Batches)
                .FirstOrDefaultAsync(s => s.HouseholdId == user!.HouseholdId && s.ProductId == productId);

            if (stock == null) return NotFound("Produto não encontrado.");

            var loteAEditar = stock.Batches.Where(b => b.Quantity > 0).OrderBy(b => b.ExpirationDate.HasValue ? 0 : 1).ThenBy(b => b.ExpirationDate).FirstOrDefault();

            if (loteAEditar != null)
            {
                loteAEditar.ExpirationDate = request.ExpirationDate;
                loteAEditar.DaysToAlertBeforeExpiration = request.DaysToAlertBeforeExpiration;
                await _context.SaveChangesAsync();

                // AVISAR TELEMÓVEIS DA CASA
                await _hubContext.Clients.Group(user!.HouseholdId.ToString()!).SendAsync("UpdateStock");
            }

            return Ok(new { Message = "Validade atualizada." });
        }

        [HttpDelete("{productId}")]
        public async Task<IActionResult> RemoveProduct(int productId)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);

            var stock = await _context.Stocks.Include(s => s.Batches)
                .FirstOrDefaultAsync(s => s.HouseholdId == user!.HouseholdId && s.ProductId == productId);

            if (stock == null) return NotFound("Produto não encontrado.");

            _context.StockBatches.RemoveRange(stock.Batches);
            _context.Stocks.Remove(stock);
            await _context.SaveChangesAsync();

            // AVISAR TELEMÓVEIS DA CASA
            await _hubContext.Clients.Group(user!.HouseholdId.ToString()!).SendAsync("UpdateStock");

            return Ok(new { Message = "Produto apagado da despensa." });
        }

        [HttpGet("shopping-list")]
        public async Task<IActionResult> GetShoppingList()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);

            var itemsToBuy = await _context.Stocks
                .Include(s => s.Batches)
                .Where(s => s.HouseholdId == user!.HouseholdId && s.MinAlertThreshold > 0 && s.Batches.Sum(b => b.Quantity) <= s.MinAlertThreshold)
                .Select(s => new
                {
                    ProdutoId = s.ProductId,
                    NomeProduto = _context.Products.FirstOrDefault(p => p.Id == s.ProductId)!.Name,
                    Categoria = _context.Products.FirstOrDefault(p => p.Id == s.ProductId)!.Category ?? "Outros",
                    Medida = _context.Products.FirstOrDefault(p => p.Id == s.ProductId)!.Measure,
                    QuantidadeAtual = s.Batches.Sum(b => b.Quantity),
                    AlertaMinimo = s.MinAlertThreshold
                })
                .ToListAsync();

            if (!itemsToBuy.Any()) return Ok(new { message = "A tua despensa está em dia!" });
            return Ok(itemsToBuy);
        }

        // ==========================================
        // MOTOR IA
        // ==========================================
        private async Task<string> InferirCategoriaComIA(string nomeProduto)
        {
            // Lê a chave do appsettings.json de forma segura
            string geminiApiKey = _configuration["GeminiApiKey"];

            if (string.IsNullOrEmpty(geminiApiKey))
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

        public class ConsumeDto
        {
            public decimal QuantityToConsume { get; set; }
        }

        [HttpPut("consume/{id}")]
        public async Task<IActionResult> ConsumeProduct(int id, [FromBody] ConsumeDto request)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);
            if (user?.HouseholdId == null) return BadRequest("Casa não encontrada.");

            var stock = await _context.Stocks.Include(s => s.Batches)
                .FirstOrDefaultAsync(s => s.HouseholdId == user.HouseholdId && s.ProductId == id);

            if (stock == null) return NotFound("Produto não encontrado na despensa.");

            decimal qtyToConsume = request.QuantityToConsume;

            var lotesOrdenados = stock.Batches
                .Where(b => b.Quantity > 0)
                .OrderBy(b => b.ExpirationDate.HasValue ? 0 : 1)
                .ThenBy(b => b.ExpirationDate)
                .ToList();

            foreach (var lote in lotesOrdenados)
            {
                if (qtyToConsume <= 0) break;

                if (lote.Quantity <= qtyToConsume)
                {
                    qtyToConsume -= lote.Quantity;
                    lote.Quantity = 0;
                }
                else
                {
                    lote.Quantity -= qtyToConsume;
                    qtyToConsume = 0;
                }
            }

            await _context.SaveChangesAsync();

            // AVISAR TELEMÓVEIS DA CASA
            await _hubContext.Clients.Group(user.HouseholdId.ToString()!).SendAsync("UpdateStock");

            return Ok(new { Message = "Consumido com sucesso!" });
        }
    }
}