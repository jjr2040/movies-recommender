from django.shortcuts import render
from django.core.paginator import Paginator, PageNotAnInteger, EmptyPage
from django.http import JsonResponse

from .models import User

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