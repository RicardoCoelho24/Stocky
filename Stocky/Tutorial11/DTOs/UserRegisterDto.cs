using System.ComponentModel.DataAnnotations;

namespace Tutorial11.DTOs
{
    public class UserRegisterDto
    {
        [Required]
        public string Name { get; set; } = string.Empty;
        [Required]
        public string Username { get; set; } = string.Empty;

        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        [MinLength(6, ErrorMessage = "A password deve ter pelo menos 6 caracteres.")]
        public string Password { get; set; } = string.Empty;
    }
}