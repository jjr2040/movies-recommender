from django.db import models

from neomodel import (
    config, 
    StructuredNode, 
    StringProperty, 
    IntegerProperty,
    FloatProperty, 
    RelationshipTo, 
    StructuredRel 
)


class Country(StructuredNode):
    country = StringProperty(unique_index=True, required=True)
    countryUri = StringProperty(unique_index=True)


class Actor(StructuredNode):
    actor = StringProperty(unique_index=True, required=True)
    acted_in = RelationshipTo('Movie', 'ACTS')


class Gender(StructuredNode):
    gender = StringProperty(unique_index=True, required=True)


class Director(StructuredNode):
    director = StringProperty(unique_index=True, required=True)
    directorUri = StringProperty(unique_index=True)
    directed = RelationshipTo('Movie', 'DIRECTS')


class Language(StructuredNode):
    language = StringProperty(unique_index=True, required=True)


class Movie(StructuredNode):
    movieId = StringProperty(unique_index=True, required=True)
    title = StringProperty(required=True)
    dbpediaLink = StringProperty(unique_index=True, required=True)
    runtime = IntegerProperty()
    made_in = RelationshipTo('Country', 'MADE_IN')
    is_classified_as = RelationshipTo('Gender', 'IS_CLASSIFIED_AS')
    is_available_in = RelationshipTo('Language', 'IS_AVAILABLE')

    @property
    def gender_names(self):
        genders_list = list(self.is_classified_as.all())
        return ', '.join(list(map(lambda x: x.gender, genders_list))) 

    @property
    def country_names(self):
        country_list = list(self.made_in.all())
        return ', '.join(list(map(lambda x: x.country, country_list)))

    @property
    def language_names(self):
        language_list = list(self.is_available_in.all())
        return ', '.join(list(map(lambda x: x.language, language_list)))  


class Studio(StructuredNode):
    studio = StringProperty(unique_index=True, required=True)
    produced = RelationshipTo('Movie', 'PRODUCES')


class Writer(StructuredNode):
    writer = StringProperty(unique_index=True, required=True)
    writerUri = StringProperty(unique_index=True)
    writed = RelationshipTo('Moview', 'WRITES')


class RatedRel(StructuredRel):
    rating = FloatProperty(required=True)


class User(StructuredNode):
    userId = StringProperty(unique_index=True, required=True)
    rated = RelationshipTo('Movie', 'RATED', model=RatedRel)
