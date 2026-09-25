using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tutorial11.Migrations
{
    /// <inheritdoc />
    public partial class AddHouseholdRequests : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "OwnerId",
                table: "Households",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "HouseholdRequests",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    HouseholdId = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HouseholdRequests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HouseholdRequests_Households_HouseholdId",
                        column: x => x.HouseholdId,
                        principalTable: "Households",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_HouseholdRequests_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_HouseholdRequests_HouseholdId",
                table: "HouseholdRequests",
                column: "HouseholdId");

            migrationBuilder.CreateIndex(
                name: "IX_HouseholdRequests_UserId",
                table: "HouseholdRequests",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "HouseholdRequests");

            migrationBuilder.DropColumn(
                name: "OwnerId",
                table: "Households");
        }
    }
}
