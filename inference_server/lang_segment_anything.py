from PIL import Image
from lang_sam import LangSAM
import numpy as np
import cv2
import time

model = LangSAM()
# image_pil = Image.open("./desk.jpeg").convert("RGB")
#image_pil = Image.open("treehacks-2024-filedrop.jepg").convert("RGB")
# text_prompt = "laptop"


# NEXT STEP: make it a serve

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()


class ImageRequest(BaseModel):
    image: str

@app.post("/find/{request}")
def read_root(request: str, image_req: ImageRequest):
    img = Image.open(BytesIO(base64.b64decode(image_req.image))).convert("RGB")
    text_prompt = request

    start_time = time.time()
    masks, boxes, phrases, logits = model.predict(image_pil, text_prompt)
    print(time.time() - start_time)


    box = [int(b) for b in boxes[0]]
    img = img_np[int(box[1]):int(box[3]), int(box[0]):int(box[2])]

    return { 'x': (box[1]+box[3])/2, 'y': (box[0]+box[2])/2 }



# #print(masks)
# print(boxes)
#
# box = boxes[0]
# img_np = np.array(image_pil)
# img = img_np[int(box[1]):int(box[3]), int(box[0]):int(box[2])]
#
# Image.fromarray(img).save("filtered_image.jpg")
#
# #print(masks.sum)
# #
# #cv2.imshow("masked", img)
# #cv2.waitKey(0)
