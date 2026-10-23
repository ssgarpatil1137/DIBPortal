using System;
using System.Security.Cryptography;

namespace DFM.Web.Infrastructure
{
    public static class PasswordSecurity
    {
        public static void CreateHash(string password, out byte[] salt, out byte[] hash)
        {
            salt = new byte[32];
            using (var random = RandomNumberGenerator.Create()) random.GetBytes(salt);
            using (var derive = new Rfc2898DeriveBytes(password, salt, 120000)) hash = derive.GetBytes(32);
        }

        public static bool Verify(string password, byte[] salt, byte[] expected)
        {
            byte[] actual;
            using (var derive = new Rfc2898DeriveBytes(password, salt, 120000)) actual = derive.GetBytes(32);
            var difference = actual.Length ^ expected.Length;
            for (var index = 0; index < actual.Length && index < expected.Length; index++) difference |= actual[index] ^ expected[index];
            return difference == 0;
        }

        public static string Token()
        {
            var bytes = new byte[32];
            using (var random = RandomNumberGenerator.Create()) random.GetBytes(bytes);
            return Convert.ToBase64String(bytes);
        }
    }
}
