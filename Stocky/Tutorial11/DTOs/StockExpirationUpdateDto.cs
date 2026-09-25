using System;

namespace Tutorial11.DTOs
{
    public class StockExpirationUpdateDto
    {
        public DateTime? ExpirationDate { get; set; }
        public int? DaysToAlertBeforeExpiration { get; set; }
    }
}