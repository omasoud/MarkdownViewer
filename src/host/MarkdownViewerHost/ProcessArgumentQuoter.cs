// ProcessArgumentQuoter - Helper for building process argument strings
// .NET Framework 4.8.1 doesn't have ProcessStartInfo.ArgumentList,
// so we need to properly quote arguments for the Arguments string.

using System.Text;

namespace MarkdownViewerHost
{
    /// <summary>
    /// Provides methods to properly quote process arguments according to Windows CreateProcess rules.
    /// </summary>
    public static class ProcessArgumentQuoter
    {
        /// <summary>
        /// Quote a single argument according to Windows CreateProcess rules.
        /// </summary>
        /// <param name="arg">The argument to quote.</param>
        /// <returns>A properly quoted argument string.</returns>
        public static string QuoteArgument(string arg)
        {
            if (string.IsNullOrEmpty(arg)) return "\"\"";

            bool needQuotes = false;
            foreach (char c in arg)
            {
                if (char.IsWhiteSpace(c) || c == '"') { needQuotes = true; break; }
            }
            // Also quote if argument ends with a backslash to ensure correct escaping
            if (!needQuotes && arg.EndsWith("\\")) needQuotes = true;
            if (!needQuotes) return arg;

            var sb = new StringBuilder();
            sb.Append('"');
            int backslashes = 0;
            for (int i = 0; i < arg.Length; i++)
            {
                char c = arg[i];
                if (c == '\\')
                {
                    backslashes++;
                }
                else if (c == '"')
                {
                    // Escape all backslashes (double them), then escape the quote
                    sb.Append('\\', backslashes * 2 + 1);
                    sb.Append('"');
                    backslashes = 0;
                }
                else
                {
                    if (backslashes > 0)
                    {
                        sb.Append('\\', backslashes);
                        backslashes = 0;
                    }
                    sb.Append(c);
                }
            }

            // Escape trailing backslashes
            if (backslashes > 0)
            {
                sb.Append('\\', backslashes * 2);
            }

            sb.Append('"');
            return sb.ToString();
        }
    }
}
