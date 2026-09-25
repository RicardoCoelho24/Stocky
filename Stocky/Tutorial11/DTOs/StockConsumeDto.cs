using System.ComponentModel.DataAnnotations;

namespace Tutorial11.DTOs
{
    public class StockConsumeDto
    {
        [Required]
        public int ProductId { get; set; }

        [Required]
        public decimal QuantityToConsume { get; set; } // Quantidade a retirar (ex: 1, ou 0.5)
    }
}