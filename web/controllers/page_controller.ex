defmodule ElixirJobs.PageController do
  use ElixirJobs.Web, :controller

  alias Exrethinkdb.Query
  alias ElixirJobs.Repo

  plug :authenticate when action in [:new, :show]
  plug :attach_sessions

  def index(conn, params) do

    q = Query.table("jobs")
    q = case params["type"] do
      "job_status" ->
        q |> Query.filter(%{job_status: params["q"]})
      "job_type" ->
        q |> Query.filter(%{job_type: params["q"]})
      "location" ->
        q |> Query.filter(%{location: params["q"]})
      _ -> q
    end
    jobs = Repo.run(q)

    q = Query.table("devs")
    devs = Repo.run(q)


    current_dev = q
      |> Query.filter(%{email: get_session(conn, :user)})
      |> Repo.run

    if get_session(conn, :user) && List.first(current_dev.data) do
      current_dev = List.first(current_dev.data)
    else
      current_dev = nil
    end

    conn
    |> assign(:jobs, jobs.data)
    |> assign(:devs, devs.data)
    |> assign(:count_jobs, Dict.size(jobs.data))
    |> assign(:count_devs, Dict.size(devs.data))
    |> assign(:current_dev, current_dev)
    |> render("index.html")
  end

  def show(conn, %{"id" => id}) do
    q = Query.table("jobs")
      |> Query.filter(%{id: id})

    result = Repo.run(q)

    job = hd(result.data)

    views =
      case is_nil(job["views"]) do
        true ->
          1
        false ->
          job["views"] + 1
      end

    Query.table("jobs")
      |> Query.get(id)
      |> Query.update(%{views: views})
      |> Repo.run

    conn
    |> assign(:job, job)
    |> assign(:page_title, job["title"] <> " - " <> job["company"] <> " | Elixir Career")
    |> render("show.html")
  end

  def new(conn, _params) do
    render conn, "new.html"
  end

  def create(conn, params) do
    job = %{
      title: params["title"],
      company: params["company"],
      description: params["description"],
      email: params["email"],
      job_type: params["job_type"],
      location: params["location"],
      job_status: params["job_status"],
      logo: params["logo"],
      posted_by: get_session(conn, :user),
      date_created: :os.system_time(:seconds)
      }

    q = Query.table("jobs")
    |> Query.insert(job)
    Repo.run(q)

    conn
    |> put_flash(:info, "Yay! Job posted!!")
    |> redirect(to: "/")
  end

  def edit(conn, %{"id" => id}) do
    q = Query.table("jobs")
      |> Query.filter(%{"id": id, "posted_by": get_session(conn, :user)})
    result = Repo.run(q)
    if List.first(result.data) do
      job = hd(result.data)
      conn
      |> assign(:job, job)
      |> assign(:page_title, job["title"] <> " - " <> job["company"] <> " | Elixir Career")
      |> render("edit.html")
    else
      conn
      |> put_flash(:error, "You are not authorized!!")
      |> redirect(to: "/")
    end
  end

  def update(conn, params) do
    job = job_params(conn, params)
    q = Query.table("jobs")
        |> Query.filter(%{"id": job.id, "posted_by": get_session(conn, :user)})
        |> Query.update(job)
    Repo.run(q)
    conn
    |> put_flash(:info, "Yay! Job post updated!!")
    |> redirect(to: page_path(conn, :show, job.id))
  end

  def delete(conn, %{"id" => id}) do
    q = Query.table("jobs")
      |> Query.filter(%{"id": id, "posted_by": get_session(conn, :user)})
      |> Query.delete()
    Repo.run(q)
    conn
    |> put_flash(:info, "Yay! Job post deleted!!")
    |> redirect(to: "/")
  end

  defp authenticate(conn, params) do
    if is_nil(get_session(conn, :user)) do
        conn
        |> put_flash(:error, "You need to login first")
        |> put_flash(:redir, conn.request_path)
        |> redirect(to: "/users/login") |> halt
    else
      conn
    end
  end

  defp attach_sessions(conn, _params) do
    conn |> assign(:user, get_session(conn, :user))
  end

  def job_params(conn, params) do
    %{
      id: params["id"],
      title: params["title"],
      company: params["company"],
      description: params["description"],
      email: params["email"],
      job_type: params["job_type"],
      location: params["location"],
      job_status: params["job_status"],
      logo: params["logo"],
      posted_by: get_session(conn, :user)
    }
  end

end
