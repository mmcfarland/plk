package main

import (
	"code.google.com/p/gcfg"
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	_ "github.com/bmizerany/pq"
	"github.com/gorilla/mux"
	"log"
	"net/http"
	"strconv"
)

type Hdl func(w http.ResponseWriter, r *http.Request)
type Parcel struct {
	OpaNum int `json:"opa"`
}

type Config struct {
	Database struct {
		Name string
		User string
	}
}

var (
	port       = flag.Int("port", 7979, "Server Port")
	DbConn     *sql.DB
	ConnString string
)

func setupDb() (db *sql.DB) {
	db, err := sql.Open("postgres", ConnString)
	if err != nil {
		log.Fatalf("Bad db conn: %v", err)
	}
	return
}

func ParcelMarshal(w http.ResponseWriter, p *Parcel, err error) {
	if err != nil {
		fmt.Println(err)
		http.Error(w, "Could not find parcel", 404)
		return
	}

	b, _ := json.Marshal(p)
	w.Write(b)
}

func ByCoords(w http.ResponseWriter, r *http.Request) {
	lat, err := strconv.ParseFloat(r.FormValue("lat"), 32)
	if err != nil {
		http.Error(w, "Bad 'lat' value", 500)
		return
	}
	lon, err := strconv.ParseFloat(r.FormValue("lon"), 32)
	if err != nil {
		http.Error(w, "Bad 'lon' value", 500)
		return
	}

	pt := fmt.Sprintf("POINT (%f %f)", lon, lat)
	sql := `SELECT brt_id 
            FROM pwd_parcels
            WHERE ST_Intersects(ST_GeomFromText($1, 4326), geom) = true;`
	s, err := DbConn.Prepare(sql)
	var p Parcel
	fmt.Println(pt)
	if err != nil {
		fmt.Println(err)
	}
	err = s.QueryRow(pt).Scan(&p.OpaNum)
	ParcelMarshal(w, &p, err)
}

func main() {
	flag.Parse()
	defer DbConn.Close()

	var conf Config
	err := gcfg.ReadFileInto(&conf, "settings.conf")
	if err != nil {
		fmt.Println("Invalid setting.conf file", err)
		return
	}
	ConnString = fmt.Sprintf("user=%s dbname=%s", conf.Database.User, conf.Database.Name)
	DbConn = setupDb()

	r := mux.NewRouter()
	api := r.PathPrefix("/api/v0.1").Subrouter()
	api.StrictSlash(false)
	api.HandleFunc("/parcel/", ByCoords).Queries("lat", "", "lon", "")
	//api.Handle("/parcel/", ByAddress).Queries("address", "")
	//api.Handle("/parcel/", ByRegMap).Queries("regmap", "")
	//api.Handle("/parcel/", ByOpa).Queries("opa", "")

	http.Handle("/", r)
	p := strconv.Itoa(*port)
	if err := http.ListenAndServe(":"+p, nil); err != nil {
		fmt.Println("Failed to start server: %v", err)
	} else {
		fmt.Println("Serving on port: " + p)
	}
}
