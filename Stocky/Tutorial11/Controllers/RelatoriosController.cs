using ClosedXML.Excel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tutorial11.Data;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class RelatoriosController : ControllerBase
    {
        private readonly AppDbContext _context;

        public RelatoriosController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("mensal/excel")]
        // [Authorize] // Retira o comentário se já tiveres o login ativo e a proteger as rotas
        public async Task<IActionResult> ExportarExcelMensal([FromQuery] int ano, [FromQuery] int mes)
        {
            // 1. Ir à Base de Dados buscar as compras do mês pedido (Usamos PurchaseDate conforme o modelo)
            var comprasDoMes = await _context.Purchases
                .Where(c => c.PurchaseDate.Year == ano && c.PurchaseDate.Month == mes)
                .OrderBy(c => c.PurchaseDate)
                .ToListAsync();

            if (!comprasDoMes.Any())
            {
                return NotFound("Não existem compras registadas para este mês.");
            }

            // 2. Criar o ficheiro Excel em Memória
            using var workbook = new XLWorkbook();
            var worksheet = workbook.Worksheets.Add($"Despesas {mes}-{ano}");

            // 3. Desenhar o Cabeçalho (Linha 1)
            worksheet.Cell(1, 1).Value = "Data da Compra";
            worksheet.Cell(1, 2).Value = "ID Supermercado"; // Alterado para bater certo com a tua BD
            worksheet.Cell(1, 3).Value = "Total Gasto (€)";

            // Pintar o Cabeçalho de Azul e Letra Branca para ficar bonito
            var cabecalho = worksheet.Range("A1:C1");
            cabecalho.Style.Fill.BackgroundColor = XLColor.Teal;
            cabecalho.Style.Font.FontColor = XLColor.White;
            cabecalho.Style.Font.Bold = true;

            // 4. Preencher com os dados das compras
            int row = 2;
            decimal totalGastoNoMes = 0;

            foreach (var compra in comprasDoMes)
            {
                // Usamos PurchaseDate e SupermarketId conforme as propriedades reais
                worksheet.Cell(row, 1).Value = compra.PurchaseDate.ToString("dd/MM/yyyy");
                worksheet.Cell(row, 2).Value = compra.SupermarketId;
                worksheet.Cell(row, 3).Value = compra.TotalAmount;
                worksheet.Cell(row, 3).Style.NumberFormat.Format = "€ #,##0.00"; // Formata para Euros

                totalGastoNoMes += compra.TotalAmount;
                row++;
            }

            // 5. Linha de Total no fim
            worksheet.Cell(row, 2).Value = "TOTAL DO MÊS:";
            worksheet.Cell(row, 2).Style.Font.Bold = true;
            worksheet.Cell(row, 3).Value = totalGastoNoMes;
            worksheet.Cell(row, 3).Style.Font.Bold = true;
            worksheet.Cell(row, 3).Style.NumberFormat.Format = "€ #,##0.00";

            // Ajustar o tamanho das colunas para caber o texto perfeitamente
            worksheet.Columns().AdjustToContents();

            // 6. Preparar o ficheiro para Download
            using var stream = new MemoryStream();
            workbook.SaveAs(stream);
            var content = stream.ToArray();

            // Retorna o ficheiro binário
            return File(
                content,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Relatorio_Compras_{mes}_{ano}.xlsx"
            );
        }
    }
}