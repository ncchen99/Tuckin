from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from routers import group, restaurant, user, utils

app = FastAPI(
    title="TuckIn API",
    description="學生交友與聚餐平台的API服務",
    version="0.1.0"
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
app.include_router(group.router, prefix="/api/group", tags=["群組管理"])
app.include_router(restaurant.router, prefix="/api/restaurant", tags=["餐廳管理"])
app.include_router(user.router, prefix="/api/user", tags=["用戶資料"])
app.include_router(utils.router, prefix="/api/utils", tags=["通用工具"])

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True) 