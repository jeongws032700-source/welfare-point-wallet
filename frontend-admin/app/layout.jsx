import Providers from "./providers";
import "./style.css";

export const metadata = { title: "사내 복지포인트 운영자 콘솔" };

export default function RootLayout({ children }) {
  return (
    <html lang="ko">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
