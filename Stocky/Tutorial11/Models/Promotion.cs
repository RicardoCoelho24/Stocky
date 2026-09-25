namespace Tutorial11.Models
{
    public class Promotion
    {
        public int Id { get; set; }
        public string Nome { get; set; } = string.Empty;
        public decimal PrecoPromocional { get; set; }
        public string Supermercado { get; set; } = string.Empty;
        public DateTime DataDeteccao { get; set; } = DateTime.UtcNow;
    }
}