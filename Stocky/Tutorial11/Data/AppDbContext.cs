using Microsoft.EntityFrameworkCore;
using Tutorial11.Models; // Isto faz a ligação com a nova pasta que criámos

namespace Tutorial11.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        // Mapeamento das tabelas utilizando os modelos reais
        public DbSet<User> Users { get; set; }
        public DbSet<Supermarket> Supermarkets { get; set; }
        public DbSet<Product> Products { get; set; }
        public DbSet<Purchase> Purchases { get; set; }
        public DbSet<PurchaseItem> PurchaseItems { get; set; }
        public DbSet<Stock> Stocks { get; set; }
        public DbSet<StockBatch> StockBatches { get; set; }
        public DbSet<Household> Households { get; set; }
        public DbSet<HouseholdRequest> HouseholdRequests { get; set; }
        public DbSet<Promotion> Promotions { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Isto resolve todos os avisos de "No store type was specified"
            modelBuilder.Entity<Purchase>().Property(p => p.TotalAmount).HasPrecision(18, 2);
            modelBuilder.Entity<PurchaseItem>().Property(pi => pi.Quantity).HasPrecision(18, 2);
            modelBuilder.Entity<PurchaseItem>().Property(pi => pi.UnitPrice).HasPrecision(18, 2);
            modelBuilder.Entity<PurchaseItem>().Property(pi => pi.TotalPrice).HasPrecision(18, 2);
            modelBuilder.Entity<Stock>().Property(s => s.MinAlertThreshold).HasPrecision(18, 2);
            modelBuilder.Entity<StockBatch>().Property(sb => sb.Quantity).HasPrecision(18, 2);
        }
    }
}