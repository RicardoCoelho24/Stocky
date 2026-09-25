using BCrypt.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Tutorial11.Data;
using Tutorial11.DTOs;
using Tutorial11.Models;
using Tutorial11.Services;

namespace Tutorial11.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly EmailService _emailService;

        public AuthController(AppDbContext context, IConfiguration configuration, EmailService emailService)
        {
            _context = context;
            _configuration = configuration;
            _emailService = emailService;
        }

        // ==========================================
        // 1. REGISTO DE UTILIZADOR
        // ==========================================
        [HttpPost("register")]
        public async Task<ActionResult> Register(UserRegisterDto request)
        {
            if (await _context.Users.AnyAsync(u => u.Email == request.Email))
            {
                return BadRequest(new { message = "Este email já está registado." });
            }

            // 1. Criar a nova Casa
            var novaCasa = new Household
            {
                Name = $"Casa de {request.Name}",
                InviteCode = GerarCodigoConvite()
            };

            _context.Households.Add(novaCasa);
            await _context.SaveChangesAsync(); // A casa ganha um ID

            string passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);

            // 2. Criar o Utilizador e associar à Casa
            var user = new User
            {
                Name = request.Name,
                Username = request.Username,
                Email = request.Email,
                PasswordHash = passwordHash,
                HouseholdId = novaCasa.Id,
                CreatedAt = DateTime.UtcNow,
                EmailConfirmed = false,
                VerificationToken = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32))
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync(); // O utilizador ganha um ID

            // 3. Definir o Utilizador como Dono da Casa
            novaCasa.OwnerId = user.Id;
            await _context.SaveChangesAsync();

            // ENVIAR EMAIL DE VERIFICAÇÃO 
            var verifyUrl = $"{Request.Scheme}://{Request.Host}/api/Auth/verify?token={user.VerificationToken}";

            string mensagemEmail = $@"
                <div style='font-family: Arial, sans-serif;'>
                    <h2>Bem-vindo(a) à Gestão de Compras, {user.Name}!</h2>
                    <p>Para começares a usar a aplicação, por favor ativa a tua conta clicando no botão abaixo:</p>
                    <a href='{verifyUrl}' style='display:inline-block;padding:10px 20px;background-color:#009688;color:white;text-decoration:none;border-radius:5px;'>Ativar Minha Conta</a>
                    <br><p style='margin-top:20px; color:gray;'>Ou copia e cola este link no teu browser: <br>{verifyUrl}</p>
                </div>";

            await _emailService.EnviarEmailAsync(user.Email, "Ativa a tua conta - Gestão de Compras", mensagemEmail);

            return Ok(new
            {
                message = "Registo concluído! Por favor, verifica o teu email (e a pasta de SPAM) para ativares a conta.",
                Casa = novaCasa.Name,
                CodigoConvite = novaCasa.InviteCode
            });
        }

        // ==========================================
        // 2. VERIFICAÇÃO DE EMAIL
        // ==========================================
        [HttpGet("verify")]
        public async Task<IActionResult> VerifyEmail([FromQuery] string token)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.VerificationToken == token);
            if (user == null) return BadRequest("Código de verificação inválido ou a conta já foi ativada.");

            user.EmailConfirmed = true;
            user.VerificationToken = null;
            await _context.SaveChangesAsync();

            return Content("<html><body style='text-align:center;font-family:sans-serif;padding:50px;'>" +
                "<h1 style='color:teal;'>Conta ativada com sucesso! ✅</h1>" +
                "<p>Já podes voltar à aplicação e iniciar sessão.</p></body></html>", "text/html");
        }

        // ==========================================
        // 3. LOGIN DE UTILIZADOR
        // ==========================================
        [HttpPost("login")]
        public async Task<ActionResult> Login(UserLoginDto request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null) return BadRequest(new { message = "Utilizador não encontrado." });

            if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
            {
                return BadRequest(new { message = "Password incorreta." });
            }

            if (!user.EmailConfirmed)
            {
                if (user.CreatedAt < new DateTime(2026, 6, 9, 0, 0, 0, DateTimeKind.Utc))
                {
                    user.EmailConfirmed = true;
                    await _context.SaveChangesAsync();
                }
                else
                {
                    return BadRequest(new { message = "Conta não verificada. Vai ao teu email e clica no link de ativação." });
                }
            }

            string token = CriarToken(user);
            return Ok(new { Token = token, HouseholdId = user.HouseholdId });
        }

        // ==========================================
        // 4. ATUALIZAR PERFIL (Nome e Foto)
        // ==========================================
        [Authorize]
        [HttpPut("update-profile")]
        public async Task<IActionResult> UpdateProfile(UpdateProfileDto request)
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();

            var user = await _context.Users.FindAsync(int.Parse(userIdStr));
            if (user == null) return NotFound(new { message = "Utilizador não encontrado." });

            user.Name = request.Nome ?? user.Name;

            if (!string.IsNullOrEmpty(request.FotoBase64))
            {
                user.ProfilePictureBase64 = request.FotoBase64;
            }

            await _context.SaveChangesAsync();

            string novoToken = CriarToken(user);
            return Ok(new { token = novoToken });
        }

        // ==========================================
        // 5. RECUPERAÇÃO DE PASSWORD
        // ==========================================
        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordDto request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);

            if (user == null) return Ok(new { message = "Se o email existir, enviámos instruções." });

            user.ResetToken = new Random().Next(100000, 999999).ToString();
            user.ResetTokenExpires = DateTime.UtcNow.AddMinutes(15);

            await _context.SaveChangesAsync();

            string mensagemEmail = $@"
                <div style='font-family: Arial, sans-serif; text-align: center;'>
                    <h2>Recuperação de Palavra-Passe</h2>
                    <p>Foi pedido um reset de palavra-passe para a tua conta na app <b>Stocky</b>.</p>
                    <p>O teu código de segurança é:</p>
                    <h1 style='color: teal; letter-spacing: 4px; font-size: 32px;'>{user.ResetToken}</h1>
                    <p>Insere este código na aplicação para criares uma nova palavra-passe.</p>
                    <p><small style='color: gray;'>Se não foste tu que pediste isto, podes ignorar este email.</small></p>
                </div>";

            await _emailService.EnviarEmailAsync(user.Email, "Recuperar Palavra-passe - Gestão de Compras", mensagemEmail);

            return Ok(new { message = "Se o email existir, enviámos as instruções de recuperação." });
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordDto request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.ResetToken == request.Token);

            if (user == null || user.ResetTokenExpires < DateTime.UtcNow)
                return BadRequest(new { message = "O código de segurança é inválido ou já expirou." });

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
            user.ResetToken = null;
            user.ResetTokenExpires = null;

            await _context.SaveChangesAsync();

            return Ok(new { message = "Palavra-passe alterada com sucesso! Já podes fazer login." });
        }

        // ==========================================
        // MÉTODOS AUXILIARES E ESTATÍSTICAS
        // ==========================================
        private string CriarToken(User user)
        {
            List<Claim> claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Name),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim("HouseholdId", user.HouseholdId.ToString() ?? ""),
                new Claim("username", user.Username ?? "")
            };

            if (!string.IsNullOrEmpty(user.ProfilePictureBase64))
            {
                claims.Add(new Claim("profilePicture", user.ProfilePictureBase64));
            }

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration.GetSection("Jwt:Key").Value!));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha512Signature);

            var token = new JwtSecurityToken(
                claims: claims,
                expires: DateTime.UtcNow.AddDays(30),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        private string GerarCodigoConvite()
        {
            var random = new Random();
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            return new string(Enumerable.Repeat(chars, 6)
                .Select(s => s[random.Next(s.Length)]).ToArray());
        }

        [HttpGet("stats")]
        [Authorize]
        public async Task<IActionResult> GetProfileStats()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim);

            var user = await _context.Users.FindAsync(userId);
            if (user == null) return NotFound();

            decimal gastosMeus = 0;
            decimal gastosCasa = 0;
            int totalProdutos = 0;

            if (user.HouseholdId != null)
            {
                // 1. Gastos da Casa (Soma total das faturas)
                gastosCasa = await _context.Purchases
                    .Where(p => p.HouseholdId == user.HouseholdId)
                    .SumAsync(p => p.TotalAmount);

                // 2. Os Meus Gastos
                gastosMeus = await _context.Purchases
                    .Where(p => p.HouseholdId == user.HouseholdId && p.UserId == userId)
                    .SumAsync(p => p.TotalAmount);

                // 3. Produtos Atuais na Despensa - CORRIGIDO
                totalProdutos = await _context.Stocks
                    .Where(s => s.HouseholdId == user.HouseholdId && s.Batches.Sum(b => b.Quantity) > 0)
                    .CountAsync();
            }

            return Ok(new
            {
                totalProdutos = totalProdutos,
                gastosMeus = gastosMeus,
                gastosCasa = gastosCasa
            });
        }
    }
}