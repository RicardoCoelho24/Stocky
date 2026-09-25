using System.ComponentModel.DataAnnotations;

namespace Tutorial11.DTOs
{
    public class UpdateCategoryDto
    {
        [Required]
        public string Category { get; set; }
    }
}