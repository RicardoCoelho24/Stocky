using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tutorial11.Data;
using Tutorial11.Models;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SupermarketsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public SupermarketsController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/Supermarkets (Lista todos os supermercados)
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Supermarket>>> GetSupermarkets()
        {
            return await _context.Supermarkets.ToListAsync();
        }

        // POST: api/Supermarkets (Adiciona um novo supermercado)
        [HttpPost]
        public async Task<ActionResult<Supermarket>> PostSupermarket(Supermarket supermarket)
        {
            _context.Supermarkets.Add(supermarket);
            await _context.SaveChangesAsync();

            return Ok(supermarket);
        }
    }
}