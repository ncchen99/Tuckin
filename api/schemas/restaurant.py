from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID

class RestaurantBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    category: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = Field(None, max_length=500)
    address: Optional[str] = Field(None, max_length=200)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    image_path: Optional[str] = Field(None, max_length=200)
    business_hours: Optional[str] = Field(None, max_length=200)

class RestaurantCreate(RestaurantBase):
    google_place_id: Optional[str] = Field(None, max_length=100)

class RestaurantResponse(RestaurantBase):
    id: UUID
    created_at: datetime

    class Config:
        orm_mode = True

class RestaurantVoteBase(BaseModel):
    restaurant_id: str
    group_id: str
    user_id: str
    vote_value: int = Field(..., ge=1, le=5)

class RestaurantVoteCreate(RestaurantVoteBase):
    pass

class RestaurantVote(RestaurantVoteBase):
    id: UUID
    created_at: datetime

    class Config:
        orm_mode = True

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
        orm_mode = True 