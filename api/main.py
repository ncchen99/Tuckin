import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from routers import restaurant, matching, dining, schedule


logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="Tuckin API",
    description="Tuckin 的 API 服務",
    version="0.1.1"
)

# 設置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 在生產環境中應更改為實際域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 註冊路由
app.include_router(restaurant.router, prefix="/api/restaurant", tags=["餐廳管理"])
app.include_router(matching.router, prefix="/api/matching", tags=["配對系統"])
app.include_router(dining.router, prefix="/api/dining", tags=["聚餐管理"])
app.include_router(schedule.router, prefix="/api/schedule", tags=["排程管理"])

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True) 