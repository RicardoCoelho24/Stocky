using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using Tutorial11.Data;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class DashboardController : ControllerBase
    {
        private readonly AppDbContext _context;

        public DashboardController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("summary")]
        public async Task<ActionResult> GetDashboardSummary([FromQuery] DateTime? date)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);

            // Carrega todas as faturas da Casa inteira para os cálculos
            var purchases = await _context.Purchases
                .Where(p => p.HouseholdId == user!.HouseholdId)
                .ToListAsync();

            var targetDate = date ?? DateTime.Today;

            int dayOfWeek = targetDate.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)targetDate.DayOfWeek;
            DateTime startOfWeek = targetDate.AddDays(-(dayOfWeek - 1));
            DateTime endOfWeek = startOfWeek.AddDays(6);

            DateTime startOfMonth = new DateTime(targetDate.Year, targetDate.Month, 1);
            DateTime endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);

            DateTime startOfYear = new DateTime(targetDate.Year, 1, 1);
            DateTime endOfYear = new DateTime(targetDate.Year, 12, 31);

            decimal gastoSemana = purchases.Where(p => p.PurchaseDate.Date >= startOfWeek && p.PurchaseDate.Date <= endOfWeek).Sum(p => p.TotalAmount);
            decimal gastoMes = purchases.Where(p => p.PurchaseDate.Date >= startOfMonth && p.PurchaseDate.Date <= endOfMonth).Sum(p => p.TotalAmount);
            decimal gastoAno = purchases.Where(p => p.PurchaseDate.Date >= startOfYear && p.PurchaseDate.Date <= endOfYear).Sum(p => p.TotalAmount);

            decimal mediaSemana = 0, mediaMes = 0, mediaAno = 0;
            if (purchases.Any())
            {
                var primeiraCompra = purchases.Min(p => p.PurchaseDate);
                var diasDesdeInicio = (DateTime.Today - primeiraCompra.Date).TotalDays;
                if (diasDesdeInicio < 1) diasDesdeInicio = 1;

                var totalGastoGeral = purchases.Sum(p => p.TotalAmount);

                mediaSemana = totalGastoGeral / (decimal)(diasDesdeInicio / 7.0 < 1 ? 1 : diasDesdeInicio / 7.0);
                mediaMes = totalGastoGeral / (decimal)(diasDesdeInicio / 30.436875 < 1 ? 1 : diasDesdeInicio / 30.436875);
                mediaAno = totalGastoGeral / (decimal)(diasDesdeInicio / 365.25 < 1 ? 1 : diasDesdeInicio / 365.25);
            }

            var gastosPorMes = purchases
                .Where(p => p.PurchaseDate.Year == targetDate.Year)
                .GroupBy(p => p.PurchaseDate.Month)
                .Select(g => new { Mes = g.Key, Total = g.Sum(p => p.TotalAmount) })
                .OrderBy(g => g.Mes)
                .ToList();

            var userPurchasesIds = purchases.Where(p => p.PurchaseDate.Year == targetDate.Year).Select(p => p.Id).ToList();

            var top10Produtos = await _context.PurchaseItems
                .Where(pi => userPurchasesIds.Contains(pi.PurchaseId))
                .GroupBy(pi => pi.ProductId)
                .Select(g => new { ProductId = g.Key, Quantidade = g.Sum(pi => pi.Quantity) })
                .OrderByDescending(g => g.Quantidade)
                .Take(10)
                .Select(g => new {
                    Nome = _context.Products.FirstOrDefault(p => p.Id == g.ProductId).Name ?? "Desconhecido",
                    Quantidade = g.Quantidade
                })
                .ToListAsync();

            // ==========================================
            // CORREÇÃO FEITA ABAIXO (pi.Price -> pi.UnitPrice)
            // ==========================================
            var gastosPorCategoria = await _context.PurchaseItems
                .Include(pi => pi.Product)
                .Where(pi => userPurchasesIds.Contains(pi.PurchaseId))
                .GroupBy(pi => pi.Product.Category ?? "Outros")
                .Select(g => new {
                    Categoria = g.Key,
                    Total = g.Sum(pi => pi.UnitPrice * pi.Quantity)
                })
                .OrderByDescending(g => g.Total)
                .ToListAsync();

            return Ok(new
            {
                GastoSemana = gastoSemana,
                GastoMes = gastoMes,
                GastoAno = gastoAno,
                MediaSemana = mediaSemana,
                MediaMes = mediaMes,
                MediaAno = mediaAno,
                GastosPorMes = gastosPorMes,
                Top10Produtos = top10Produtos,
                GastosPorCategoria = gastosPorCategoria
            });
        }
    }
}