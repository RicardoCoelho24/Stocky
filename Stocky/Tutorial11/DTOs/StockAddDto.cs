using System.ComponentModel.DataAnnotations;

using System.ComponentModel.DataAnnotations;

namespace Tutorial11.DTOs
{
    public class StockAddDto
    {
        [Required]
        public int ProductId { get; set; }

        [Required]
        public decimal QuantityToAdd { get; set; }
    }
}