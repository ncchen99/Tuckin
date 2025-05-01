from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID

class RestaurantBase(BaseModel):
    name: str
    category: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    image_path: Optional[str] = None
    business_hours: Optional[str] = None
    google_place_id: Optional[str] = None
    is_user_added: bool = False
    phone: Optional[str] = None
    website: Optional[str] = None

class RestaurantCreate(RestaurantBase):
    pass

class RestaurantResponse(RestaurantBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True
        orm_mode = True

class Restaurant(RestaurantBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True
        orm_mode = True

class RestaurantVoteBase(BaseModel):
    restaurant_id: str
    group_id: str
    user_id: Optional[str] = None
    is_system_recommendation: bool = False

class RestaurantVoteCreate(RestaurantVoteBase):
    pass

class RestaurantVote(RestaurantVoteBase):
    id: UUID
    created_at: datetime
    is_voting_complete: Optional[bool] = False
    dining_event_id: Optional[str] = None
    winning_restaurant: Optional[dict] = None

    class Config:
        from_attributes = True
        orm_mode = True

class RestaurantSearchQuery(BaseModel):
    query: Optional[str] = None
    category: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    radius: Optional[int] = 5000  # meters
    limit: int = 10
    
class GroupRestaurantVotesResponse(BaseModel):
    group_id: str
    restaurants: List[Restaurant]
    user_votes: List[RestaurantVote]
    system_recommendations: List[Restaurant] = []
    
class UserVoteRequest(BaseModel):
    group_id: str
    restaurant_id: str

class UserVoteCreate(BaseModel):
    restaurant_id: str
    is_system_recommendation: bool = False

class RatingBase(BaseModel):
    restaurant_id: str
    user_id: str
    score: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=500)
    uncomfortable_rating: Optional[bool] = False

class RatingCreate(RatingBase):
    pass

class Rating(RatingBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True
        orm_mode = True 