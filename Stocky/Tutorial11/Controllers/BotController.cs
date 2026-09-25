using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Tutorial11.Data;
using Tutorial11.Hubs;
using Tutorial11.Models;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class BotController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IHubContext<HouseholdHub> _hubContext;

        private const string BOT_SECRET_KEY = "SuperSecretBotKey123!";

        public BotController(AppDbContext context, IHubContext<HouseholdHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        public class PromocaoDto
        {
            public string Nome { get; set; } = string.Empty;
            public decimal PrecoPromocional { get; set; }
            public string Supermercado { get; set; } = string.Empty;
        }

        [HttpPost("promocoes")]
        public async Task<IActionResult> ReceberPromocoes([FromHeader(Name = "x-bot-key")] string botKey, [FromBody] List<PromocaoDto> promocoes)
        {
            if (botKey != BOT_SECRET_KEY) return Unauthorized("Acesso negado.");
            if (promocoes == null || !promocoes.Any()) return BadRequest("Lista vazia.");

            var nomeSupermercado = promocoes.First().Supermercado;

            // NOVA REDE DE SEGURANÇA: Garante que o Supermercado vem preenchido!
            if (string.IsNullOrEmpty(nomeSupermercado))
            {
                return BadRequest("O bot não enviou a identificação do Supermercado!");
            }

            // APAGA APENAS AS PROMOÇÕES DESTE SUPERMERCADO ESPECÍFICO
            var promocoesAntigas = await _context.Promotions
                .Where(p => p.Supermercado == nomeSupermercado)
                .ToListAsync();

            _context.Promotions.RemoveRange(promocoesAntigas);

            // GUARDA AS NOVAS
            foreach (var promo in promocoes)
            {
                _context.Promotions.Add(new Promotion
                {
                    Nome = promo.Nome,
                    PrecoPromocional = promo.PrecoPromocional,
                    Supermercado = promo.Supermercado,
                    DataDeteccao = DateTime.UtcNow
                });
            }
            await _context.SaveChangesAsync();

            await _hubContext.Clients.All.SendAsync("UpdatePromocoes");

            return Ok(new { Mensagem = $"{promocoes.Count} promoções do {nomeSupermercado} guardadas com sucesso na Base de Dados!" });
        }

        [HttpGet("activas")]
        [Authorize]
        public async Task<IActionResult> GetPromocoesAtivas()
        {
            var promocoes = await _context.Promotions
                .OrderByDescending(p => p.DataDeteccao)
                .Select(p => new
                {
                    nome = p.Nome,
                    preco = p.PrecoPromocional,
                    supermercado = p.Supermercado
                })
                .ToListAsync();

            return Ok(promocoes);
        }
    }
}