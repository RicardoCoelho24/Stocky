namespace Tutorial11.Models
{
    public class User
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;

        // Propriedades adicionadas para o AuthController deixar de dar erro
        public string Username { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public string Email { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;

        public int? HouseholdId { get; set; }
        public Household? Household { get; set; }
        // Adiciona isto dentro da tua classe User:
        public string? ProfilePictureBase64 { get; set; } // Para guardar a foto de perfil
        public bool EmailConfirmed { get; set; } = false; // Bloqueia o login se for false
        public string? VerificationToken { get; set; } // O código enviado no email de registo

        public string? ResetToken { get; set; } // O código enviado no "Esqueci-me da passe"
        public DateTime? ResetTokenExpires { get; set; } // Validade do código de recuperação
    }
}