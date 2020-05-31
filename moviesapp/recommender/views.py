from django.shortcuts import render
from django.core.paginator import Paginator, PageNotAnInteger, EmptyPage
from django.http import JsonResponse

from .models import User, Movie
from neomodel import db

user_list = User.nodes.all()

def index(request):
    global user_list
    page = request.GET.get('page', 1)

    local_users = user_list
    
    userId = request.GET.get('userId')
    
    if userId:
        local_users = User.nodes.filter(userId=userId)

    paginator = Paginator(local_users, 10)
    try:
        users = paginator.page(page)
    except PageNotAnInteger:
        users = paginator.page(1)
    except EmptyPage:
        users = paginator.page(paginator.num_pages)

    return render(request, 'index.html', { 'users': users })


def add_user(request):
    global user_list
    new_user = User(userId=str(len(user_list) + 1))
    new_user.save()

    user_list.append(new_user)
    data = { 'allright': True, 'userId': new_user.userId }
    return JsonResponse(data)


def recommended_movies(request, user_id):

    query = """MATCH (baseUser: User {{ userId: '{0}'}})-[baseRating:RATED]->(m: Movie)
WITH avg(baseRating.rating) AS baseAvgRating
MATCH (u1: User {{ userId: '{0}'}})-[r1:RATED]->(m1: Movie)<-[r2:RATED]-(u2: User)-[r3:RATED]->(m2: Movie)<-[:PRODUCES]-(studio:Studio)-[:PRODUCES]->(m1)
WHERE NOT(u1)-[:RATED]->(m2) AND m1 <> m2 AND r1.rating > baseAvgRating AND r2.rating > baseAvgRating AND r3.rating > baseAvgRating
WITH DISTINCT m2.title AS RecommendedMovie, m2
RETURN m2 
LIMIT 10
    """.format(user_id)

    results, meta = db.cypher_query(query)

    movies = [Movie.inflate(row[0]) for row in results]
    context = {
        'user_id': user_id,
        'movies': movies 
    }
    return render(request, 'movie_recommendations.html', context=context)