using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;
using Tutorial11.Data;
using Tutorial11.Hubs;
using Tutorial11.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddScoped<EmailService>();
builder.Services.AddSignalR();

// 1. Configurar o Swagger para aceitar e enviar o Token JWT
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Insere o token JWT desta forma: Bearer {o_teu_token_gigante}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            new string[] {}
        }
    });
});

// Configuração da ligação ao SQL Server
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// 2. Configurar o sistema de Autenticação para validar os Tokens
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(
                builder.Configuration.GetSection("Jwt:Key").Value!)),
            ValidateIssuer = false,
            ValidateAudience = false
        };
    });

// 3. Configurar a política de CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("PermitirTudo", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// ==========================================
// Ativar o CORS (Tem de estar antes da Autenticação)
// ==========================================
app.UseCors("PermitirTudo");

// ==========================================
// CONFIGURAÇÃO PARA ALOJAR O SITE WEB (FLUTTER)
// ==========================================
app.UseDefaultFiles(); // <-- A LINHA QUE FALTAVA (Procura pelo index.html)
app.UseStaticFiles();  // Permite que os ficheiros na pasta wwwroot sejam lidos e mostrados

// IMPORTANTE: A ordem destas duas linhas é vital para a segurança!
app.UseAuthentication(); // 1º Vê quem tu és (Lê o Token)
app.UseAuthorization();  // 2º Vê se tens permissão para entrar

app.MapControllers();
app.MapHub<HouseholdHub>("/householdHub");

app.Run();