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

//Una vez creadas las relaciones, eliminar los atributos del usuario
MATCH  (u:User)
REMOVE u.ratings
REMOVE u.timestamps
REMOVE u.moviesIds
RETURN u

-----------------------------Cargar usuarios y su relacion--------------------------------

CREATE CONSTRAINT ON (u:User) ASSERT u.userId IS UNIQUE;

LOAD CSV WITH HEADERS FROM "file:///unique_users.csv" AS userId
CREATE (u:User {userId:userId.userId})

:auto USING PERIODIC COMMIT 500
LOAD CSV WITH HEADERS FROM "file:///ratings.csv" AS rating
MATCH (m:Movie)
WHERE m.movieId = rating.movieId
MATCH (u:User)
WHERE u.userId = rating.userId
MERGE (u)-[rel:RATED {rating: toFloat(rating.rating), timestamp: toInteger(rating.timestamp)} ]->(m)
RETURN count(rel)

------------------------------COMANDOS EXTRAS--------------------------------

// Ratings to float
MATCH (user:User)-[rated:RATED]->(movie:Movie)
SET rated.rating = toFloat(rated.rating)

// GDC Alg
MATCH (p:User), (m:Movie)
OPTIONAL MATCH (p)-[rated:RATED]->(m)
WITH {item:id(p), weights: collect(coalesce(rated.rating, gds.util.NaN()))} AS userData
WITH collect(userData) AS data
CALL gds.alpha.similarity.pearson.stream({
 nodeProjection: '*',
 relationshipProjection: '*',
 data: data,
 topK: 3,
 similarityCutoff: 0.1
})
YIELD item1, item2, count1, count2, similarity
RETURN gds.util.asNode(item1).userId AS from, gds.util.asNode(item2).userId AS to, similarity
ORDER BY similarity DESC

// GDC Algoritmo Write (NO corre por memoria)
MATCH (p:Person), (m:Movie)
OPTIONAL MATCH (p)-[rated:RATED]->(m)
WITH {item: id(p), weights: collect(coalesce(rated.rating, gds.util.NaN()))} AS userData
WITH collect(userData) AS data
CALL gds.alpha.similarity.pearson.write({
 nodeProjection: '*',
 relationshipProjection: '*',
 data: data,
 topK: 3,
 similarityCutoff: 0.1
})
YIELD nodes, similarityPairs, writeRelationshipType, writeProperty, min, max, mean, stdDev, p25, p50, p75, p90, p95, p99, p999, p100
RETURN nodes, similarityPairs, writeRelationshipType, writeProperty, min, max, mean, p95

// GDC Algoritmo light
WITH "MATCH (user:User)-[rated:RATED]->(movie: Movie)
      OPTIONAL MATCH (user)-[rated:RATED]->(movie)
      RETURN id(user) AS item, id(movie) AS category, rated.rating AS weight" AS query
CALL gds.alpha.similarity.pearson.write({
  nodeProjection: '*',
  relationshipProjection: '*',
  data: query,
  graph: 'cypher',
  topK: 3,
  similarityCutoff: 0.1
})
YIELD nodes, similarityPairs, writeRelationshipType, writeProperty, min, max, mean, stdDev, p25, p50, p75, p90, p95, p99, p999, p100
RETURN nodes, similarityPairs, writeRelationshipType, writeProperty, min, max, mean, p95

// Normal Collaborative search
MATCH (tom:Person {name: 'Tom Hanks'})-[:ACTED_IN]->(movie1:Movie)<-[:ACTED_IN]-(coActor:Person)-[:ACTED_IN]->(movie2:Movie)<-[:ACTED_IN]-(cruise:Person {name: 'Tom Cruise'})
WHERE NOT (tom)-[:ACTED_IN]->(:Movie)<-[:ACTED_IN]-(cruise)
RETURN tom, movie1, coActor, movie2, cruise

MATCH (u1: User { userId: '282356'})-[r1:RATED]->(m1: Movie)<-[r2:RATED]-(u2: User)-[r3:RATED]->(m2: Movie)
WHERE NOT(u1)-[:RATED]->(m2) AND m1 <> m2 AND toFloat(r1.rating) > 4 AND toFloat(r2.rating) > 4 AND toFloat(r3.rating) > 4
RETURN u1.userId AS FirstUser, u2.userId AS SeconUser, m1.title AS CommonMovie, m2.title AS RecommendedMovie LIMIT 50

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


