---
layout: page
# title: Recipes
permalink: /recipes
---

<h1>My Recipes (Cooking)</h1>

<div class="recipes-list">
  {% for recipe in site.recipes %}
    <div class="recipe-item">
      <h3><a href="{{ recipe.url | relative_url }}">{{ recipe.title }}</a></h3>
      {% if recipe.description %}
        <p>{{ recipe.description }}</p>
      {% endif %}
      {% if recipe.date %}
        <p class="recipe-date">{{ recipe.date | date: "%B %d, %Y" }}</p>
      {% endif %}
    </div>
  {% endfor %}
</div>