import Providers from "./providers";
import "./style.css";

export const metadata = { title: "사내 복지포인트 지갑" };

export default function RootLayout({ children }) {
  return (
    <html lang="ko">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
