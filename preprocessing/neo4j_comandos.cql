//Creacion de constraints
CREATE CONSTRAINT ON (m:Movie) ASSERT m.movieId IS UNIQUE;
CREATE CONSTRAINT ON (c:Country) ASSERT c.countryUri IS UNIQUE;
CREATE CONSTRAINT ON (d:Director) ASSERT d.directorUri IS UNIQUE;
CREATE CONSTRAINT ON (w:Writer) ASSERT w.writerUri IS UNIQUE;
CREATE CONSTRAINT ON (g:Gender) ASSERT g.gender IS UNIQUE;
CREATE CONSTRAINT ON (l:Language) ASSERT l.language IS UNIQUE;
CREATE CONSTRAINT ON (st:Studio) ASSERT st.studio IS UNIQUE;
CREATE CONSTRAINT ON (a:Actor) ASSERT a.actor IS UNIQUE;

//Creacion del grafo
LOAD CSV WITH HEADERS FROM "file:///movies_enriched.csv" AS movie
CREATE (m:Movie {movieId:movie.movieId,title:movie.title,dbpediaLink:movie.dbpedia_link})
FOREACH (x IN CASE WHEN movie.country IS NULL OR movie.country_uri IS NULL THEN [] ELSE [1] END |
  MERGE (c:Country {country: movie.country})
  CREATE (m)-[:MADE_IN]->(c)
)
FOREACH (x IN CASE WHEN movie.director IS NULL OR movie.director_uri IS NULL THEN [] ELSE [1] END |
  MERGE (d:Director {director: movie.director,directorUri:movie.director_uri})
  CREATE (d)-[:DIRECTS]->(m)
)
FOREACH (x IN CASE WHEN movie.writer IS NULL OR movie.writer_uri IS NULL THEN [] ELSE [1] END |
  MERGE (w:Writer{writer: movie.writer,writerUri:movie.writer_uri})
  CREATE (w)-[:WRITES]->(m)
)
FOREACH (x IN CASE WHEN movie.genres IS NULL THEN [] ELSE [1] END |
FOREACH (y IN split(movie.genres,"|")| MERGE (g:Gender {gender: split(y,",")[0]})
CREATE (m)-[:IS_CLASSIFIED_AS]->(g)))
FOREACH (x IN CASE WHEN movie.starring IS NULL THEN [] ELSE [1] END |
FOREACH (y IN split(movie.starring,"|")| MERGE (s:Actor {actor: split(y,",")[0]})
 CREATE (a)-[:ACT]->(m)
))
FOREACH (x IN CASE WHEN movie.languagues IS NULL THEN [] ELSE [1] END |
FOREACH (y IN split(movie.languagues,"|")| MERGE (l:Language {language: split(y,",")[0]})
CREATE (m)-[:IS_AVAILABLE]->(l)))
FOREACH (x IN CASE WHEN movie.studios IS NULL THEN [] ELSE [1] END |
FOREACH (y IN split(movie.studios,"|")| MERGE (st:Studio {studio: split(y,",")[0]})
CREATE (st)-[:PRODUCES]->(m)))
FOREACH (x IN CASE WHEN movie.runtime IS NULL THEN [] ELSE [1] END |
  SET m.runtime=toInteger(movie.runtime)/60
)


//Cargar archivo de ratings
CREATE CONSTRAINT ON (u:User) ASSERT u.userId IS UNIQUE;

LOAD CSV WITH HEADERS FROM "file:///prueba.csv" AS rating
CREATE (u:User {userId:rating.userId, moviesIds:split(rating.moviesId,"|"),ratings:split(rating.ratings,"|"),timestamps:split(rating.timestamps,"|")})


//Crear relaciones de usuarios a peliculas
MATCH (u:User),(m:Movie)
WHERE m.movieId IN u.moviesIds
CREATE (u)-[r:SEES{rating:u.ratings[1+[x IN range(0,size(u.ratings)-1) WHERE u.moviesIds[x] = m.movieId][0]],timestamp:u.timestamps[1+[y IN range(0,size(u.timestamps)-1) WHERE u.moviesIds[y] = m.movieId][0]]}]->(m)
RETURN r


LOAD CSV WITH HEADERS FROM "file:///ratings.csv" AS ratings
MATCH (from:User {userId: ratings.userId}),(to:Movie {movieId:ratings.movieId})
CREATE (from)-[rel:RATED  {rating: ratings.rating }]->(to)

-----------------------------Cargar usuarios y su relacion--------------------------------

CREATE CONSTRAINT ON (u:User) ASSERT u.userId IS UNIQUE;

LOAD CSV WITH HEADERS FROM "file:///unique_users.csv" AS userId
CREATE (u:User {userId:userId.userId})

LOAD CSV WITH HEADERS FROM "file:///ratings.csv" AS rating
MATCH (u:User) WHERE u.userId=rating.userId
MATCH (m:Movie) WHERE m.movieId=rating.movieId
MERGE (u)-[rel:RATED {rating: rating.rating, timestamp: rating.timestamp} ]->(m)
CREATE (u)-[rel:RATED {rating: rating.rating, timestamp: rating.timestamp} ]->(m)

LOAD CSV WITH HEADERS FROM "file:///ratings.csv" AS rating
MATCH (u:User {userId: rating.userId}), (m:Movie {movieId: rating.movieId})
MERGE (u)-[rel:RATED {rating: rating.rating, timestamp: rating.timestamp} ]->(m)

:auto USING PERIODIC COMMIT 500
LOAD CSV WITH HEADERS FROM "file:///ratings.csv" AS rating
MATCH (m:Movie)
WHERE m.movieId = rating.movieId
MATCH (u:User)
WHERE u.userId = rating.userId
MERGE (u)-[rel:RATED {rating: rating.rating, timestamp: rating.timestamp} ]->(m)
RETURN count(rel)

------------------------------COMANDOS EXTRAS--------------------------------

// Pearson similarity
MATCH (p1:User {name: 'Cynthia Freeman'})-[x:RATED]->(movie:Movie)
WITH p1, algo.similarity.asVector(movie, x.rating) AS p1Vector
MATCH (p2:User)-[x2:RATED]->(movie:Movie) WHERE p2 <> p1
WITH p1, p2, p1Vector, algo.similarity.asVector(movie, x2.rating) AS p2Vector
WHERE size(apoc.coll.intersection([v in p1Vector | x.category], [v in p2Vector | v.category])) > 10
RETURN p1.name AS from,
       p2.name AS to,
       algo.similarity.pearson(p1Vector, p2Vector, {vectorType: "maps"}) AS similarity
ORDER BY similarity DESC
LIMIT 100

//Comando para revisar duplicados
MATCH  (g:Director) WHERE g.director="Abel Ferrara"
RETURN count(g) as count

//Comando para consultar relaciones
MATCH (Director { director: 'Abel Ferrara' })--(Movie)
RETURN Movie.title

//Comando para borrar todo
MATCH (n) DETACH DELETE n

//Elimar relaciones de un tipo
MATCH ()-[r:SEES]->()  
DELETE r



