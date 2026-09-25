using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tutorial11.Migrations
{
    /// <inheritdoc />
    public partial class AddUsersAndHousehold : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "HouseholdId",
                table: "Users",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Name",
                table: "Users",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "HouseholdId",
                table: "Stocks",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "HouseholdId",
                table: "Purchases",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Households",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    InviteCode = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Households", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_HouseholdId",
                table: "Users",
                column: "HouseholdId");

            migrationBuilder.CreateIndex(
                name: "IX_Stocks_HouseholdId",
                table: "Stocks",
                column: "HouseholdId");

            migrationBuilder.CreateIndex(
                name: "IX_Purchases_HouseholdId",
                table: "Purchases",
                column: "HouseholdId");

            migrationBuilder.AddForeignKey(
                name: "FK_Purchases_Households_HouseholdId",
                table: "Purchases",
                column: "HouseholdId",
                principalTable: "Households",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Stocks_Households_HouseholdId",
                table: "Stocks",
                column: "HouseholdId",
                principalTable: "Households",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Users_Households_HouseholdId",
                table: "Users",
                column: "HouseholdId",
                principalTable: "Households",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Purchases_Households_HouseholdId",
                table: "Purchases");

            migrationBuilder.DropForeignKey(
                name: "FK_Stocks_Households_HouseholdId",
                table: "Stocks");

            migrationBuilder.DropForeignKey(
                name: "FK_Users_Households_HouseholdId",
                table: "Users");

            migrationBuilder.DropTable(
                name: "Households");

            migrationBuilder.DropIndex(
                name: "IX_Users_HouseholdId",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Stocks_HouseholdId",
                table: "Stocks");

            migrationBuilder.DropIndex(
                name: "IX_Purchases_HouseholdId",
                table: "Purchases");

            migrationBuilder.DropColumn(
                name: "HouseholdId",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Name",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "HouseholdId",
                table: "Stocks");

            migrationBuilder.DropColumn(
                name: "HouseholdId",
                table: "Purchases");
        }
    }
}
