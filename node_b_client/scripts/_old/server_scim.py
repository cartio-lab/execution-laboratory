from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI()
fake_db = {}

class User(BaseModel):
    userName: str
    displayName: str
    active: bool = True

@app.post("/Users")
async def create_user(user: User):
    if user.userName in fake_db:
        raise HTTPException(status_code=409, detail="User exists")
    fake_db[user.userName] = user
    return user

@app.put("/Users/{username}")
async def update_user(username: str, user: User):
    fake_db[username] = user
    return user

@app.delete("/Users/{username}")
async def delete_user(username: str):
    if username in fake_db:
        del fake_db[username]
    return {"status": "deleted"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")
