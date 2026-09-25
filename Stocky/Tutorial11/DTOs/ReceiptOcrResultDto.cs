namespace Tutorial11.DTOs
{
    // Representa um único produto lido da fatura
    public class OcrItemDto
    {
        public string ProductName { get; set; } = string.Empty;
        public decimal Quantity { get; set; } = 1;
        public decimal UnitPrice { get; set; }
    }

    // Representa a fatura inteira
    public class ReceiptOcrResultDto
    {
        public string SupermarketName { get; set; } = string.Empty;

        // NOVO: A IA agora vai preencher este campo com o total poupado!
        public decimal TotalDiscount { get; set; } = 0;

        public List<OcrItemDto> Items { get; set; } = new List<OcrItemDto>();
    }
}