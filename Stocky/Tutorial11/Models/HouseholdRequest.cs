namespace Tutorial11.Models
{
    public class HouseholdRequest
    {
        public int Id { get; set; }

        public int UserId { get; set; }
        public User? User { get; set; }

        public int HouseholdId { get; set; }
        public Household? Household { get; set; }

        public string Status { get; set; } = "Pendente"; // Pode ser "Pendente", "Aceite" ou "Rejeitado"
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}