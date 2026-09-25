using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tutorial11.Data;
using Tutorial11.Models;
using Tutorial11.DTOs; // Adicionado para ler os DTOs

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class ProductsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ProductsController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Product>>> GetProducts()
        {
            return await _context.Products.ToListAsync();
        }

        [HttpPost]
        public async Task<ActionResult<Product>> PostProduct(Product product)
        {
            _context.Products.Add(product);
            await _context.SaveChangesAsync();

            return Ok(product);
        }

        // ==========================================
        // EDITAR NOME E MEDIDA DO PRODUTO (NOVO!)
        // ==========================================
        [HttpPut("{id}/edit")]
        public async Task<IActionResult> UpdateProductDetails(int id, [FromBody] UpdateProductDto request)
        {
            var produto = await _context.Products.FindAsync(id);
            if (produto == null) return NotFound("Produto não encontrado.");

            if (!string.IsNullOrWhiteSpace(request.Name))
            {
                // Limpa os espaços extra e formata a primeira letra em maiúscula
                var nomeLimpo = request.Name.Trim();
                produto.Name = char.ToUpper(nomeLimpo[0]) + nomeLimpo.Substring(1).ToLower();
            }

            // Atualiza a medida (pode vir a null se o utilizador apagar)
            produto.Measure = request.Measure?.Trim();

            await _context.SaveChangesAsync();

            return Ok(new { Message = "Produto atualizado com sucesso!" });
        }

        // PUT: api/Products/5/category
        [HttpPut("{id}/category")]
        public async Task<IActionResult> UpdateProductCategory(int id, [FromBody] UpdateCategoryDto request)
        {
            if (string.IsNullOrWhiteSpace(request.Category))
                return BadRequest("A categoria não pode estar vazia.");

            var produto = await _context.Products.FindAsync(id);
            if (produto == null) return NotFound("Produto não encontrado.");

            var novaCategoria = char.ToUpper(request.Category.Trim()[0]) + request.Category.Trim().Substring(1);
            produto.Category = novaCategoria;

            await _context.SaveChangesAsync();

            return Ok(new { Message = "Categoria atualizada com sucesso!" });
        }
    }
}

