---
layout: post
title: Build Once and Deploy Everywhere for SPAs
location: Virtual
category: Blog Post
tags: [cloud-native]
description: It's often tempting to use process.env in your frontend code. But, that means you either have to run Node in all environments or need to build the app for each location. How can we build once, deploy anywhere? In this post, we'll talk about externalizing our configuration.
excerpt: It's often tempting to use process.env in your frontend code. But, that means you either have to run Node in all environments or need to build the app for each location. How can we build once, deploy anywhere? In this post, we'll talk about externalizing our configuration.
image: /images/12factor-spa.png
uuid: 9d320c32-90ce-4bb8-be1f-bc0956713932
---

I've been working in the cloud-native and container space long enough to truly believe in the mantra of **Build Once, Deploy Anywhere.** While, yes, that's Docker's mantra, it applies in much of the cloud-native world. Containers do make this easier, but it applies in non-containerized environments too. By building once and using the same version of the code in all environments, you have a greater assurance that things will work the same way as you progress through your various environments (dev, QA, staging, prod, or whatever).

The question is... how does this work in complicated JavaScript frontends that are processed using webpack, etc.?

<div class="alert alert-info" markdown=1>
**Note:** this post doesn't apply to those that are running their apps actually using Node, but those using a simple webserver (nginx, S3, etc.) to serve previously-built static content.
</div>

## The Problem

Quite often, I see code similar to what's below. While this is a React example, the problem applies in all frontend frameworks in which webpack or any other pre-processor is involved. 

In this snippet, we have a component that fetches all of the "todos" and stores them in a state variable named `items`.

```jsx
function TodoList() {
  const [items, setItems] = useState(null);
  useEffect(() => {
      fetch(`${process.env.API_HOST}/todos`)
        .then(r => r.json())
        .then(setItems);
  }, []);

  ...
}
```

What's the problem in the snippet? It's this line:

```js
fetch(`${process.env.API_HOST}/todos`)
```

The location of the API is provided by the `API_HOST` environment variable. When we run `yarn build`, webpack swaps out the value with the current value of `API_HOST`. That means we can't change it on the fly. If we want to change the value for different environments, we have to rebuild the code.


## The Principle

If we follow [The Twelve-Factor App](https://12factor.net) principle of [Config](https://12factor.net/config), we are told to "store config in the environment." And what is config? Simply put, "an app’s config is everything that is likely to vary between deploys." Looking at our example above, one example that might vary between deploys is the value of `process.env.API_HOST`. But, we might have many others too!


## Applying the Principle

The easiest way to do this is to externalize all of the config into a `config.json` file that is not bundled in the app (meaning not loaded using `require` or `import`). Instead, we're going to simply `fetch` the config file! Then, we can simply swap out this single file in each of our environments. Let's start first with updating our codebase to work in this manner...

### Externalizing our Configuration

1. Create a `config.json` file. For a React app, I would put this at `public/config.json`. 

    ```json
    {
        "apiHost": "https://api.example.com"
    }
    ```

    This file will contain all of the application config unique to your application. So, add any and all things that will change between environments.

1. With the file defined, we simply need to fetch the file and then make the config available to the entire app. For a React app, that would mean fetching the file before rendering the app and supplying the config to the app. This would replace the normal startup in the `src/index.js`

    ```jsx
    fetch("/config.json")
        .then(r => r.json())
        .then(config => {
            ReactDOM.render(
              <React.StrictMode>
                <App config={config} />
              </React.StrictMode>,
              document.getElementById('root')
            );
        });
    ```

1. This part gets React-specific, but we're going to make the config available to the entire app using a [`Context`](https://reactjs.org/docs/context.html). So, let's make one in `src/appConfig.js`:

    ```js
    const React = require("react");

    const AppConfig = React.createContext({});

    export default AppConfig;
    ```

1. Now, let's make sure the context is given the config passed into the app. This will then let any other component in the application use this app-level config. In the `src/app.js`, we'll use the context's provider. We'll just make sure it wraps anything else we might have.

    ```js
    const AppConfig = require("./appConfig");

    function App({ config }) {
        ...

        return (
            <AppConfig.Provider value={config}>
                ...
            </AppConfig.Provider>
        )
    }
    ```

1. Now, we can update our previous `TodoList` component to use the context, leveraging the [`useContext` hook](https://reactjs.org/docs/hooks-reference.html#usecontext). We'll pass it a reference to the context, which will cause React to search up the component tree and find the global config we provided at bootstrap.

    ```jsx
    const { useContext } = require("react");
    const AppConfig = require("../path/to/appConfig");

    function TodoList() {
        const { apiHost } = useContext(AppConfig);
        const [items, setItems] = useState(null);
        useEffect(() => {
            fetch(`${apiHost}/todos`)
                .then(r => r.json())
                .then(setItems);
        }, [apiHost]);
        ...
    }
    ```

### Swapping out the Configuration

This part now becomes very specific to _how_ you are deploying your application. Here are some examples:

- If you are deploying to S3/CloudFront, you can replace the `config.json` in your bucket
- If you are using nginx, you can either replace the file or create a `location` directive to point to wherever you might have the correct config
      
    ```
    location /config.json { alias /another/path/to/config.json; }
    ```

- If you are using containers, it will largely depend on the orchestration framework you are using. But, the idea is to overlay a new file into the container's filesystem. Kubernetes makes it easy to [mount a ConfigMap as a file](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#populate-a-volume-with-data-stored-in-a-configmap) (where the ConfigMap contains the config for the app). Swarm lets you [use config objects](https://docs.docker.com/engine/swarm/configs/#simple-example-get-started-with-configs).


## Wrap-up

Hopefully, you got an idea of how to allow your front-end code to be deployed anywhere, even when built only once. If you want a few examples, feel free to check out [my DockerCon 2021 example repo](https://github.com/mikesir87/dc2021-talk-demos), where I demo this concept. If you have questions, let me know!
