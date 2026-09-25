using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Tutorial11.Models
{
    public class Stock
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }

        [Required]
        public int ProductId { get; set; }

        [Required]
        public decimal MinAlertThreshold { get; set; } = 1;

        // Relação 1 para Muitos: O produto agora tem Vários Lotes
        public ICollection<StockBatch> Batches { get; set; } = new List<StockBatch>();
        public int? HouseholdId { get; set; }
        public Household? Household { get; set; }
    }
}