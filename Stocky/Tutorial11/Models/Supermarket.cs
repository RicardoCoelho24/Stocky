namespace Tutorial11.Models
{
    public class Supermarket
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? LogoUrl { get; set; } // O ponto de interrogação significa que pode ser nulo
    }
}