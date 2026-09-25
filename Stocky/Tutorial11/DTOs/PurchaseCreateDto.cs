using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Tutorial11.DTOs
{
    public class PurchaseCreateDto
    {
        [Required]
        public string SupermarketName { get; set; }

        [Required]
        public DateTime PurchaseDate { get; set; }

        // NOVO: A porta de entrada para o desconto que vem do telemóvel!
        public decimal TotalDiscount { get; set; } = 0;

        public List<PurchaseItemDto> Items { get; set; } = new List<PurchaseItemDto>();
    }

    public class PurchaseItemDto
    {
        [Required]
        public string ProductName { get; set; }

        [Required]
        public decimal Quantity { get; set; }

        [Required]
        public decimal UnitPrice { get; set; }

        public decimal MinAlertThreshold { get; set; } = 1;

        // --- NOVOS CAMPOS PARA RECEBER A VALIDADE DA COMPRA ---
        public DateTime? ExpirationDate { get; set; }
        public int? DaysToAlertBeforeExpiration { get; set; }
    }
}