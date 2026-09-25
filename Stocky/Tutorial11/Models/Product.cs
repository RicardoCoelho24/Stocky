using System.ComponentModel.DataAnnotations;

namespace Tutorial11.Models
{
    public class Product
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string Name { get; set; }

        [Required]
        public string Category { get; set; } = "Outros";

        public string? Measure { get; set; }
    }
}