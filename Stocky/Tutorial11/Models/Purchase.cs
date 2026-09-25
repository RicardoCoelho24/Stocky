using System;

namespace Tutorial11.Models
{
    public class Purchase
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int SupermarketId { get; set; }
        public DateTime PurchaseDate { get; set; }
        public decimal TotalAmount { get; set; }

        // NOVO CAMPO: O "Mealheiro" da Poupança!
        public decimal TotalDiscount { get; set; } = 0;

        public string? ReceiptImageUrl { get; set; }
        public int? HouseholdId { get; set; }
        public Household? Household { get; set; }
    }
}