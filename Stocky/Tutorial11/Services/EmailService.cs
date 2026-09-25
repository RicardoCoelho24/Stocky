using System.Net;
using System.Net.Mail;

namespace Tutorial11.Services
{
    public class EmailService
    {
        // ATENÇÃO: Se usares Gmail, tens de ir à tua conta Google -> Segurança -> 
        // Verificação em 2 Passos -> Palavras-passe de Aplicação e gerar uma pass de 16 letras.
        private readonly string _emailOrigem = "stocky2413@gmail.com";
        private readonly string _passwordApp = "eydu epsu pzls ngfg";

        public async Task EnviarEmailAsync(string destino, string assunto, string mensagemHTML)
        {
            try
            {
                using var smtpClient = new SmtpClient("smtp.gmail.com")
                {
                    Port = 587,
                    Credentials = new NetworkCredential(_emailOrigem, _passwordApp),
                    EnableSsl = true,
                };

                var mailMessage = new MailMessage
                {
                    From = new MailAddress(_emailOrigem, "Gestão de Compras"),
                    Subject = assunto,
                    Body = mensagemHTML,
                    IsBodyHtml = true,
                };
                mailMessage.To.Add(destino);

                await smtpClient.SendMailAsync(mailMessage);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro ao enviar email: {ex.Message}");
            }
        }
    }
}