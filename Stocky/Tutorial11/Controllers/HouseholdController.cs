using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using Tutorial11.Data;
using Tutorial11.DTOs;
using Tutorial11.Models;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // Protege tudo! Só entra quem tiver o Token JWT.
    public class HouseholdController : ControllerBase
    {
        private readonly AppDbContext _context;

        public HouseholdController(AppDbContext context)
        {
            _context = context;
        }

        // ==========================================
        // 1. VER OS DADOS DA MINHA CASA
        // ==========================================
        [HttpGet("minha-casa")]
        public async Task<IActionResult> GetMinhaCasa()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdStr)) return BadRequest(new { message = "Token inválido." });

            var userId = int.Parse(userIdStr);

            var user = await _context.Users
                .Include(u => u.Household)
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user?.Household == null) return NotFound(new { message = "Casa não encontrada." });

            var moradores = await _context.Users
                .Where(u => u.HouseholdId == user.HouseholdId)
                .Select(u => new { u.Name, u.Username, Foto = u.ProfilePictureBase64 })
                .ToListAsync();

            return Ok(new
            {
                NomeCasa = user.Household.Name,
                CodigoConvite = user.Household.InviteCode,
                SouODono = user.Household.OwnerId == userId, // Diz ao Flutter se este utilizador é o administrador
                Moradores = moradores
            });
        }

        // ==========================================
        // 2. PEDIR PARA JUNTAR A UMA CASA NOVA (SALA DE ESPERA)
        // ==========================================
        [HttpPost("juntar")]
        public async Task<IActionResult> PedirParaJuntar([FromBody] JoinHouseholdDto request)
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var userId = int.Parse(userIdStr!);

            var casaDestino = await _context.Households
                .FirstOrDefaultAsync(h => h.InviteCode.ToUpper() == request.InviteCode.ToUpper().Trim());

            if (casaDestino == null)
                return BadRequest(new { message = "Código de convite inválido! Verifica se escreveste bem." });

            var user = await _context.Users.FindAsync(userId);
            if (user!.HouseholdId == casaDestino.Id)
                return BadRequest(new { message = "Já pertences a esta casa!" });

            // Verificar se já tem um pedido pendente
            bool jaPediu = await _context.HouseholdRequests
                .AnyAsync(r => r.UserId == userId && r.HouseholdId == casaDestino.Id && r.Status == "Pendente");

            if (jaPediu)
                return BadRequest(new { message = "Já enviaste um pedido para esta casa. Aguarda a aprovação!" });

            // Criar o pedido
            var novoPedido = new HouseholdRequest
            {
                UserId = userId,
                HouseholdId = casaDestino.Id,
                Status = "Pendente"
            };

            _context.HouseholdRequests.Add(novoPedido);
            await _context.SaveChangesAsync();

            return Ok(new { message = $"Pedido enviado para a {casaDestino.Name}! Aguarda que o dono aprove." });
        }

        // ==========================================
        // 3. VER PEDIDOS PENDENTES (Só o dono da casa)
        // ==========================================
        [HttpGet("pedidos-pendentes")]
        public async Task<IActionResult> VerPedidosPendentes()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var userId = int.Parse(userIdStr!);

            var user = await _context.Users.Include(u => u.Household).FirstOrDefaultAsync(u => u.Id == userId);

            // Bloqueia se o utilizador não for o dono
            if (user?.Household == null || user.Household.OwnerId != userId)
                return Forbid(); // Retorna 403 (Proibido)

            var pedidos = await _context.HouseholdRequests
                .Include(r => r.User)
                .Where(r => r.HouseholdId == user.HouseholdId && r.Status == "Pendente")
                .Select(r => new
                {
                    Id = r.Id,
                    Nome = r.User!.Name,
                    Data = r.CreatedAt
                })
                .ToListAsync();

            return Ok(pedidos);
        }

        // ==========================================
        // 4. ACEITAR OU REJEITAR PEDIDO (Só o dono)
        // ==========================================
        [HttpPost("responder-pedido/{pedidoId}")]
        public async Task<IActionResult> ResponderPedido(int pedidoId, [FromQuery] bool aceitar)
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var userId = int.Parse(userIdStr!);

            var pedido = await _context.HouseholdRequests
                .Include(r => r.Household)
                .FirstOrDefaultAsync(r => r.Id == pedidoId);

            if (pedido == null || pedido.Status != "Pendente")
                return NotFound(new { message = "Pedido não encontrado ou já processado." });

            if (pedido.Household!.OwnerId != userId)
                return Forbid();

            if (aceitar)
            {
                pedido.Status = "Aceite";
                var userNovo = await _context.Users.FindAsync(pedido.UserId);
                if (userNovo != null)
                {
                    userNovo.HouseholdId = pedido.HouseholdId; // Muda-o finalmente de casa!
                }
                await _context.SaveChangesAsync();
                return Ok(new { message = "Utilizador aceite na tua casa com sucesso!" });
            }
            else
            {
                _context.HouseholdRequests.Remove(pedido); // Se rejeitar, apaga o pedido
                await _context.SaveChangesAsync();
                return Ok(new { message = "Pedido rejeitado." });
            }
        }

        // ==========================================
        // 5. REPARAR CONTA (Criar casa de emergência)
        // ==========================================
        [HttpPost("reparar-conta")]
        public async Task<IActionResult> RepararConta()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdStr)) return BadRequest(new { message = "Token inválido." });

            var userId = int.Parse(userIdStr);
            var user = await _context.Users.Include(u => u.Household).FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null) return NotFound(new { message = "Utilizador não encontrado." });

            if (user.HouseholdId != null)
            {
                return Ok(new
                {
                    message = "A tua conta já tem uma casa perfeitamente associada!",
                    Codigo = user.Household!.InviteCode
                });
            }

            var random = new Random();
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            var codigoRandom = new string(Enumerable.Repeat(chars, 6)
                .Select(s => s[random.Next(s.Length)]).ToArray());

            var novaCasa = new Household
            {
                Name = $"Casa de {user.Name}",
                InviteCode = codigoRandom
            };

            _context.Households.Add(novaCasa);
            await _context.SaveChangesAsync();

            user.HouseholdId = novaCasa.Id;
            novaCasa.OwnerId = user.Id; // <-- AGORA O UTILIZADOR É DEFINIDO COMO DONO NA REPARAÇÃO

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Conta reparada com sucesso! A base de dados foi forçada a criar a tua casa e és o administrador.",
                CodigoConvite = novaCasa.InviteCode
            });
        }

        // ==========================================
        // 6. RECUPERAR DADOS ANTIGOS (Resgate de Produtos)
        // ==========================================
        [HttpPost("recuperar-dados")]
        public async Task<IActionResult> RecuperarDadosAntigos()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdStr)) return BadRequest(new { message = "Token inválido." });

            var userId = int.Parse(userIdStr);
            var user = await _context.Users.FindAsync(userId);

            if (user?.HouseholdId == null) return BadRequest(new { message = "Ainda não tens uma casa associada." });

            var stocksOrfaos = await _context.Stocks
                .Where(s => s.UserId == userId && s.HouseholdId == null)
                .ToListAsync();

            foreach (var stock in stocksOrfaos)
            {
                stock.HouseholdId = user.HouseholdId;
            }

            var comprasOrfaos = await _context.Purchases
                .Where(p => p.UserId == userId && p.HouseholdId == null)
                .ToListAsync();

            foreach (var compra in comprasOrfaos)
            {
                compra.HouseholdId = user.HouseholdId;
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = $"Resgate concluído! Foram recuperados {stocksOrfaos.Count} produtos e {comprasOrfaos.Count} faturas para a tua casa atual."
            });
        }
    }
}