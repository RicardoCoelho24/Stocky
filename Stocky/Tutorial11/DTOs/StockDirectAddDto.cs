using System;
using System.ComponentModel.DataAnnotations;

namespace Tutorial11.DTOs
{
    public class StockDirectAddDto
    {
        [Required]
        public string ProductName { get; set; }

        [Required]
        public decimal Quantity { get; set; }

        public decimal MinAlertThreshold { get; set; } = 1;

        public DateTime? ExpirationDate { get; set; }

        public int? DaysToAlertBeforeExpiration { get; set; }
    }
}