telegram bot token 怎么获取
獲取 Telegram Bot Token 的過程非常簡單，主要是透過 Telegram 官方提供的「機器人之父」—— BotFather 來完成。 
n8n Docs
n8n Docs
 +1
以下是詳細步驟：
1. 找到 BotFather
在 Telegram 搜尋欄輸入 @BotFather，並選擇帶有藍色打勾認證標誌的官方機器人。 
知乎专栏
知乎专栏
 +1
2. 開始對話
點擊「開始」（Start）或輸入 /start 以啟用機器人。 
n8n Docs
n8n Docs
3. 創建新機器人
輸入命令 /newbot。
設定名稱 (Name)：為你的機器人起一個暱稱（例如：我的測試助手）。
設定使用者名稱 (Username)：這是機器人的唯一識別碼，必須以 bot 結尾（例如：my_test_123_bot）。 
4. 取得 Token
成功創建後，BotFather 會發送一條包含 HTTP API Token 的訊息（格式通常為 123456789:ABCDefghIJKLmnOPqrstUVWxyz）。 
如果你已經有機器人但忘了 Token：
向 BotFather 發送 /mybots。
選擇你現有的機器人。
點擊 API Token 按鈕即可重新查看。 
Respond.io
Respond.io
⚠️ 安全提醒：
Token 是控制機器人的唯一憑證，請務必妥善保管，切勿洩露給他人。如果 Token 外流，請立即在 BotFather 處使用 /revoke 命令撤銷並更換新的 Token。
你是否還需要了解如何獲取 Chat ID 來讓機器人發送訊息？