using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Tutorial11.Data;
using Tutorial11.DTOs;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // Protegido! Só quem tem o Token entra.
    public class UsersController : ControllerBase
    {
        private readonly AppDbContext _context;

        public UsersController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/Users/me (Obtém os dados do perfil do utilizador logado)
        [HttpGet("me")]
        public async Task<ActionResult<UserProfileDto>> GetMyProfile()
        {
            // 1. Lemos o ID do crachá (Token)
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            // 2. Procuramos o utilizador na base de dados
            var user = await _context.Users.FindAsync(userId);

            if (user == null)
            {
                return NotFound("Utilizador não encontrado.");
            }

            // 3. Devolvemos apenas os dados seguros
            return Ok(new UserProfileDto
            {
                Id = user.Id,
                Name = user.Email.Split('@')[0],
                Email = user.Email
            });
        }
    }
}