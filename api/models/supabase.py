from datetime import datetime
from typing import Optional, Dict, Any, List

# 用戶資料模型
class UserProfile:
    user_id: str
    nickname: str
    gender: Optional[str]
    personal_desc: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime]

# 用戶設備令牌模型
class UserDeviceToken:
    id: str
    user_id: str
    token: str
    updated_at: datetime

# 群組模型
class Group:
    id: str
    name: str
    description: Optional[str]
    creator_id: str
    created_at: datetime

# 群組成員模型
class GroupMember:
    id: str
    group_id: str
    user_id: str
    created_at: datetime

# 群組UUID映射模型
class GroupUuidMapping:
    id: str
    group_id: str
    user_id: str
    created_at: datetime

# 餐廳模型
class Restaurant:
    id: str
    name: str
    category: Optional[str]
    description: Optional[str]
    address: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    image_path: Optional[str]
    business_hours: Optional[str]
    google_place_id: Optional[str]
    created_at: datetime

# 餐廳投票模型
class RestaurantVote:
    id: str
    restaurant_id: str
    group_id: str
    user_id: str
    vote_value: int
    created_at: datetime

# 評分模型
class Rating:
    id: str
    restaurant_id: str
    user_id: str
    score: int
    comment: Optional[str]
    uncomfortable_rating: bool
    created_at: datetime

# 聚餐事件模型
class DiningEvent:
    id: str
    group_id: str
    restaurant_id: Optional[str]
    name: str
    date: datetime
    status: str
    description: Optional[str]
    creator_id: str
    created_at: datetime

# 聚餐參與者模型
class DiningEventParticipant:
    id: str
    event_id: str
    user_id: str
    is_attending: bool
    created_at: datetime

# 匹配分數模型
class MatchingScore:
    id: str
    user_id: str
    target_user_id: str
    score: float
    last_calculated: datetime

# 通知模型
class Notification:
    id: str
    user_id: str
    title: str
    body: str
    data: Optional[Dict[str, Any]]
    created_at: datetime
    read_at: Optional[datetime] 