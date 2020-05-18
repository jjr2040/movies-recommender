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
  SET m.runtime=toString(toInteger(movie.runtime)/60)
)

//Comando para revisar duplicados
MATCH  (g:Director) WHERE g.director="Abel Ferrara"
RETURN count(g) as count

//Comando para consultar relaciones
MATCH (Director { director: 'Abel Ferrara' })--(Movie)
RETURN Movie.title

//Comando para borrar todo
MATCH (n) DETACH DELETE n





