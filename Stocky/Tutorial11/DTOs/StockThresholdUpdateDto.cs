using System.ComponentModel.DataAnnotations;

namespace Tutorial11.DTOs
{
    public class StockThresholdUpdateDto
    {
        [Required]
        public decimal NewThreshold { get; set; }
    }
}