from fastapi import APIRouter, Depends, HTTPException, status, Query
from supabase import Client
from typing import List, Optional

from schemas.restaurant import RestaurantCreate, RestaurantResponse, RestaurantVote, RestaurantVoteCreate
from dependencies import get_supabase, get_current_user

router = APIRouter()

@router.get("/search", response_model=List[RestaurantResponse])
async def search_restaurants(
    query: str,
    latitude: Optional[float] = Query(None),
    longitude: Optional[float] = Query(None),
    radius: Optional[int] = Query(1000),
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    搜索餐廳
    """
    pass

@router.post("/", response_model=RestaurantResponse, status_code=status.HTTP_201_CREATED)
async def create_restaurant(
    restaurant: RestaurantCreate,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    新增餐廳資訊到資料庫
    """
    pass

@router.get("/{restaurant_id}", response_model=RestaurantResponse)
async def get_restaurant(
    restaurant_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取餐廳詳細資訊
    """
    pass

@router.post("/vote", response_model=RestaurantVote)
async def vote_restaurant(
    vote: RestaurantVoteCreate,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    對餐廳進行投票
    """
    pass

@router.get("/group/{group_id}/votes", response_model=List[RestaurantVote])
async def get_group_restaurant_votes(
    group_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取群組中的餐廳投票
    """
    pass 