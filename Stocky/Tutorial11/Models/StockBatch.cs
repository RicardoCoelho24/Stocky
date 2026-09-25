using System;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Tutorial11.Models
{
    public class StockBatch
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int StockId { get; set; }

        [Required]
        public decimal Quantity { get; set; }

        public DateTime? ExpirationDate { get; set; }

        public int? DaysToAlertBeforeExpiration { get; set; }

        [JsonIgnore]
        public Stock Stock { get; set; }
    }
}