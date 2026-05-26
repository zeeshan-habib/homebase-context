from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI()


@app.get("/", response_class=HTMLResponse)
async def root():
    return """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>MSHR Dash</title>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background: #f2f2ec;
      color: #1e0b3a;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    header {
      background: #7e3dd4;
      color: #ffffff;
      padding: 20px 40px;
    }

    header h1 {
      font-size: 1.5rem;
      font-weight: 700;
      letter-spacing: -0.02em;
    }

    main {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 40px;
    }

    .card {
      background: #ffffff;
      border: 1px solid #e6e4d6;
      border-radius: 8px;
      padding: 48px 56px;
      text-align: center;
      max-width: 480px;
      width: 100%;
    }

    .card h2 {
      font-size: 2rem;
      font-weight: 700;
      color: #1e0b3a;
      margin-bottom: 12px;
    }

    .card p {
      font-size: 1rem;
      color: #605f56;
      line-height: 1.6;
    }

    .badge {
      display: inline-block;
      margin-top: 24px;
      background: #f1ecff;
      color: #7e3dd4;
      font-weight: 600;
      font-size: 0.8rem;
      padding: 6px 14px;
      border-radius: 999px;
    }
  </style>
</head>
<body>
  <header>
    <h1>MSHR Dash</h1>
  </header>
  <main>
    <div class="card">
      <h2>Hello from Databricks!</h2>
      <p>Your Main Street Health Report dashboard is live and ready to build on.</p>
      <span class="badge">Powered by Databricks Apps</span>
    </div>
  </main>
</body>
</html>"""
