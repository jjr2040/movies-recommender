from re import split

from django.shortcuts import render
from django.core.paginator import Paginator, PageNotAnInteger, EmptyPage
from django.http import JsonResponse

from .models import User, Movie, RatedRel
from neomodel import db
import time
from datetime import datetime

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

def ratings(request, user_id):
    query = """MATCH p=(u:User)-[r:RATED]->(m:Movie) WHERE u.userId='{0}' RETURN r,m.movieId
    """.format(user_id)

    results, meta = db.cypher_query(query)
    movies = []
    ratingsList= [RatedRel.inflate(row[0]) for row in results]

    context = {
        'user_id': user_id,
        'ratings': ratingsList
    }
    return render(request, 'user_ratings.html', context=context)

def add_rating(request):
    user_id = request.GET['user_id']
    movie_id = request.GET['movieId']
    rating = request.GET['frating']

    query = """MATCH (u:User) WHERE u.userId='{0}' RETURN u
        """.format(user_id)
    results, meta = db.cypher_query(query)

    query2 = """MATCH (m:Movie WHERE m.MovieId='{0}' RETURN m
            """.format(movie_id)
    results2, meta2 = db.cypher_query(query2)

    user = User.inflate(results)
    movie = Movie.inflate(results2)

    user.rated.connect(movie,{'rating':float(rating),'timestamp':int(time.mktime(datetime.now().timetuple()))})

    data = {'allright': True}
    return JsonResponse(data)

def recommended_movies(request, user_id):

    num_ratings = get_num_ratings(user_id)
    too_few = 10

    query = ""
    recommendation_type = ""

    if num_ratings > too_few:
        recommendation_type = "Hybrid (Collaborative based + Content based)"
        query = """MATCH (baseUser: User {{ userId: '{0}'}})-[baseRating:RATED]->(m: Movie)
        WITH avg(baseRating.rating) AS baseAvgRating
        MATCH (u1: User {{ userId: '{0}'}})-[r1:RATED]->(m1: Movie)<-[r2:RATED]-(u2: User)-[r3:RATED]->(m2: Movie)<-[:PRODUCES]-(studio:Studio)-[:PRODUCES]->(m1)
        WHERE NOT(u1)-[:RATED]->(m2) AND m1 <> m2 AND r1.rating > baseAvgRating AND r2.rating > baseAvgRating AND r3.rating > baseAvgRating
        WITH DISTINCT m2.title AS RecommendedMovie, m2
        RETURN m2 LIMIT 10
        """.format(user_id)
    elif num_ratings > 0 and num_ratings <= too_few:
        recommendation_type = "Content based"
        query = """MATCH (u1: User {{ userId: '{0}'}})-[r1:RATED]->(m1: Movie)-[r2:IS_CLASSIFIED_AS]->(g:Gender)<-[r3:IS_CLASSIFIED_AS]-(m2:Movie) 
        WHERE r1.rating > 4.5
        RETURN m2 LIMIT 10
        UNION
        MATCH (u1: User {{ userId: '{0}'}})-[r1:RATED]->(m1: Movie)<-[r2:ACTS]-(a:Actor)-[r3:ACTS]->(m2:Movie) 
        WHERE r1.rating > 4.5
        RETURN m2 LIMIT 10
        """.format(user_id)
    else:
        recommendation_type = "Popular (Generic recommendation)"
        query = """MATCH (u:User)-[r:RATED]->(m:Movie)-[:MADE_IN]->(:Country {country: 'United States'})
        WITH m, count(r.rating) as countrating, avg(r.rating) as avgrating
        WHERE avgrating > 3.5
        RETURN m
        ORDER BY countrating DESC
        LIMIT 10"""

    results, meta = db.cypher_query(query)

    movies = [Movie.inflate(row[0]) for row in results]
    context = {
        'user_id': user_id,
        'movies': movies,
        'recommendation_type': recommendation_type
    }
    return render(request, 'movie_recommendations.html', context=context)

def get_num_ratings(user_id):
    q = """MATCH (u: User {{ userId: '{0}' }})-[r:RATED]->(m:Movie) return count(m)""".format(user_id)
    r, m = db.cypher_query(q)

    return r[0][0]