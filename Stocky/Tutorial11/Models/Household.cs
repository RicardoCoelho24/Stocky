namespace Tutorial11.Models
{
    public class Household
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string InviteCode { get; set; } = string.Empty;

        // NOVO: Define quem manda na casa (o administrador)
        public int? OwnerId { get; set; }

        public ICollection<User>? Users { get; set; }
    }
}