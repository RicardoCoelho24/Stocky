using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System.Security.Claims;
using Tutorial11.Data; // Ajusta se a tua pasta de Data tiver outro nome

namespace Tutorial11.Hubs
{
    [Authorize]
    public class HouseholdHub : Hub
    {
        private readonly AppDbContext _context;

        public HouseholdHub(AppDbContext context)
        {
            _context = context;
        }

        // Esta função corre automaticamente assim que um telemóvel abre a app!
        public override async Task OnConnectedAsync()
        {
            var userIdStr = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            if (!string.IsNullOrEmpty(userIdStr))
            {
                var userId = int.Parse(userIdStr);
                var user = await _context.Users.FindAsync(userId);

                if (user?.HouseholdId != null)
                {
                    // Junta o utilizador à "Sala" da sua casa automaticamente
                    await Groups.AddToGroupAsync(Context.ConnectionId, user.HouseholdId.ToString()!);
                }
            }
            await base.OnConnectedAsync();
        }
    }
}