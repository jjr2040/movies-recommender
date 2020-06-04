from django.urls import path
from . import views

urlpatterns = [
    path('', views.index, name='index'),
    path('addUser', views.add_user),
    path('movies/<user_id>/', views.recommended_movies, name='movie_recomendations'),
    path('ratings/<user_id>/', views.ratings, name='user_ratings'),
    path('addRating', views.add_rating),
]